import assert from 'node:assert/strict';
import test from 'node:test';
import {allocateRoom, terminalRoom, assertRoomGroupMember} from '../lib/room/room-allocation.js';
import {roomCleanupDeadline, sameCleanupTarget, cleanupScanPage} from '../lib/room/room-cleanup.js';
import {withTransactionRandom, gameRandomInt, gameRandomUUID} from '../lib/common/transaction-random.js';
import {finalizeGameMutation} from '../lib/game-interruption/game-mutation.js';
import {createHoldemGame, completeHoldemDealing, excludeHoldemPlayer} from '../lib/holdem/game.js';
import {previewRecoveryExclusion} from '../lib/game-interruption/game-adapters.js';

const reservation = {roomCode:'ABCDE', roomInstanceId:'room-current', expectedAllocationGeneration:0,
  allocationGeneration:1, controllerSessionId:'controller-one', connectionId:'connection-one', createdAt:100, status:'reserved'};
const initial = {...reservation, controllerUid:'t', creationOperationId:'create-operation', status:'waiting'};

test('allocation replay and terminal generation CAS cannot resurrect or replace another room', () => {
  assert.deepEqual(allocateRoom(null,reservation,'t','create-operation',initial),initial);
  const live={...initial,controllerCurrentConnectionId:'connection-new'};
  assert.equal(allocateRoom(live,reservation,'t','create-operation',initial),live);
  const terminal=terminalRoom(live,1000);
  assert.equal(allocateRoom(terminal,reservation,'t','create-operation',initial),undefined);
  const nextReservation={...reservation,roomInstanceId:'room-next',expectedAllocationGeneration:1,allocationGeneration:2};
  const next={...initial,...nextReservation};
  assert.equal(allocateRoom(terminal,nextReservation,'t','next-operation',next),next);
  assert.equal(allocateRoom(next,reservation,'t','create-operation',initial),undefined);
  assert.equal(sameCleanupTarget(next,terminal),false);
  assert.equal(sameCleanupTarget(null,{}),false);
});

test('retention keeps the approved waiting/playing/finished boundaries and terminal tombstones', () => {
  const room={...initial,controllerPresence:{lastSeen:1000}};
  assert.equal(roomCleanupDeadline(room),181000);
  assert.equal(roomCleanupDeadline({...room,status:'playing'}),901000);
  assert.equal(roomCleanupDeadline({...room,status:'finished',retainUntil:50000}),50000);
  assert.equal(roomCleanupDeadline({...terminalRoom(room,10000),cleanupPending:false}),null);
  const compact=terminalRoom({roomInstanceId:'only-identity',allocationGeneration:2,status:'closed'},10000);
  assert.equal(Object.values(compact).includes(undefined),false);
});

test('group reads accept current active members and controller, reject arbitrary/old membership', () => {
  const room={...initial,players:{a:{status:'active'},b:{status:'left'}}};
  assert.doesNotThrow(()=>assertRoomGroupMember(room,'a','room-current'));
  assert.doesNotThrow(()=>assertRoomGroupMember(room,'t','room-current'));
  for(const uid of ['b','other'])assert.throws(()=>assertRoomGroupMember(room,uid,'room-current'));
  assert.throws(()=>assertRoomGroupMember(room,'a','room-old'));
});

test('transaction retries rewind deterministic entropy including rejection sampling', () => {
  const seed=Buffer.alloc(32,1);
  const reducer=()=>[gameRandomInt(52),gameRandomInt(1,100),gameRandomUUID(),gameRandomInt(2147483647)];
  assert.deepEqual(withTransactionRandom(seed,reducer),withTransactionRandom(seed,reducer));
  assert.notDeepEqual(withTransactionRandom(seed,reducer),withTransactionRandom(Buffer.alloc(32,2),reducer));
});

function holdemRoom() {
  const players=['a','b','c'].map((uid,seatIndex)=>({uid,seatIndex,nickname:uid,characterId:'frog'}));
  const game=createHoldemGame(players,1000);completeHoldemDealing(game,2000);
  const room={...initial,selectedGame:'holdem',status:'playing',players:Object.fromEntries(players.map(p=>[p.uid,{status:'active'}])),game};
  finalizeGameMutation(room,undefined,2000,'game-current');return room;
}
test('zero-stack all-in is a surviving player until the pots are settled; preview uses the reducer', () => {
  const room=holdemRoom();
  room.game.public.players.a.stack=0;
  room.game.server.betting.players.a.stack=0;
  room.game.server.betting.players.a.status='allIn';
  room.game.public.players.a.status='alive';
  room.game.public.turnUid='b';room.game.server.betting.turnUid='b';
  const preview=previewRecoveryExclusion(room,'c',3000);
  assert.equal(preview.canContinue,true);
  assert.notEqual(preview.room.game.public.finishReason,'insufficientPlayers');
  assert.equal(room.game.public.players.c.status,'alive','preview never writes');
  excludeHoldemPlayer(room.game,'c',3000);
  assert.notEqual(room.game.public.finishReason,'insufficientPlayers');
});
test('semantic/private changes stamp one context and invalidate an existing pause barrier', () => {
  const room=holdemRoom();const before=structuredClone(room.game);
  room.game.public.players.a.nickname='changed';
  finalizeGameMutation(room,before,3000,'ignored-new-id');
  assert.equal(room.game.public.gameInstanceId,'game-current');
  assert.equal(room.game.public.dataSeq,2);
  assert.equal(room.game.public.resumeEpoch,2);
  for(const value of Object.values(room.game.private))assert.equal(value._context.dataSeq,2);
  assert.deepEqual(room.game.server.recovery.ready,{});
});

test('persistent cleanup cursor reaches live targets after more than 500 terminal records', () => {
  const entries=Array.from({length:607},(_,index)=>({code:String(index).padStart(5,'0'),room:{...initial,status:index<600?'terminal':'playing'}}));
  let cursor=null;const visited=[];
  do {
    const response=entries.filter(entry=>cursor===null||entry.code>=cursor).slice(0,101);
    const page=cleanupScanPage(response,cursor);visited.push(...page.page.map(entry=>entry.code));cursor=page.nextCursor;
  } while(cursor!==null);
  assert.equal(visited.length,607);assert.equal(new Set(visited).size,607);assert.equal(visited.at(-1),'00606');
});
