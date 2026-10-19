import assert from 'node:assert/strict';
import test from 'node:test';
import {currentPresence} from '../lib/room/current-presence.js';
import {findGhostPlayers} from '../lib/room/ghost-player-policy.js';
import {roomCleanupDeadline} from '../lib/room/room-cleanup.js';
import {refreshCleanupSignal} from '../lib/room/cleanup-signal.js';
import {assertRoomTarget, allocateRoomConnection} from '../lib/room/session-contract.js';
import {reportStaleController} from '../lib/game-interruption/recovery-state.js';
import {createRequire} from 'node:module';
import {CleanupDatabase} from './fake-cleanup-database.mjs';
const require = createRequire(import.meta.url);
const admin = require('firebase-admin/database');
const {logger} = require('firebase-functions');
const {cleanupGhostRoomPlayers} = require('../lib/game-interruption/expire-scheduler.js');
const {cleanupStaleRealtimeRooms, syncRoomCleanupQueue} = require('../lib/room/room-cleanup.js');
const {runPrimedTransaction} = require('../lib/room/room-transaction.js');
const {createRealtimeRoom} = require('../lib/room/create-room.js');

function setup(t) {
  const database = new CleanupDatabase();
  const original = database.ref.bind(database);
  t.mock.method(database, 'ref', path => Object.assign(original(path), {
    key:path.split('/').at(-1), parent:{key:path.split('/').at(-2)}}));
  t.mock.method(admin, 'getDatabase', () => database);
  t.mock.method(logger, 'info', () => {});
  t.mock.method(Date, 'now', () => now);
  return database;
}

const now = 1_000_000;
function room() {
  return {roomInstanceId:'instance-1', allocationGeneration:1, status:'waiting',
    controllerUid:'tablet', controllerCurrentConnectionId:'c1', controllerConnectionSeq:1,
    controllerPresence:{connected:false,lastSeen:1},
    players:{phone:{status:'active',role:'player',membershipId:'member-1',currentConnectionId:'p1',connectionSeq:1,isConnected:false,lastSeen:1}},
    connections:{tablet:{c1:{roomInstanceId:'instance-1',connectionSeq:1,connected:true,lastSeen:now}},
      phone:{p1:{roomInstanceId:'instance-1',membershipId:'member-1',connectionSeq:1,connected:true,lastSeen:now}}}};
}
test('P1: fresh current leaf protects ghost and room despite frozen false summary', () => {
  const r = room();
  assert.deepEqual(findGhostPlayers({room:r,roomStatus:r.status,players:r.players,now}), []);
  assert.equal(roomCleanupDeadline(r), now + 180000);
  r.status = 'playing';
  assert.equal(roomCleanupDeadline(r), now + 900000);
});
test('P1: connected=true cannot permanently exempt controller expiry; explicit deadlines win', () => {
  const r = room(); r.connections.tablet.c1.lastSeen = 1;
  assert.equal(roomCleanupDeadline(r), 180001);
  r.status='closed'; r.cleanupAt=42;
  assert.equal(roomCleanupDeadline(r), 42);
  r.status='finished'; r.retainUntil=43;
  assert.equal(roomCleanupDeadline(r), 43);
});
test('canonical selection rejects old generation, membership and other role', () => {
  const r = room();
  r.connections.phone.p1.membershipId='old';
  assert.equal(currentPresence(r,'phone','player'), undefined);
  r.connections.tablet.c1.connectionSeq=0;
  assert.equal(currentPresence(r,'tablet','controller'), undefined);
  assert.equal(currentPresence(r,'tablet','player'), undefined);
});

test('B1 missing canonical fails closed for destructive cleanup', () => {
  const r=room(); r.presenceProtocol=2; delete r.connections;
  assert.equal(roomCleanupDeadline(r), null);
  assert.deepEqual(findGhostPlayers({room:r,roomStatus:r.status,players:r.players,now}), []);
});
test('old APK cannot create new rooms or perform database work', async t => {
  const db=setup(t);
  await assert.rejects(createRealtimeRoom.run({auth:{uid:'tablet'},data:{operationId:'create-operation'}}),
    error=>error.details?.reason==='upgradeRequired');
  assert.deepEqual(db.reads,[]);
  assert.deepEqual(db.data,{});
});
test('signal does not change on heartbeat/card/profile; lifecycle revisions remain monotonic', () => {
  const r=room(); refreshCleanupSignal(r); const first=structuredClone(r.cleanupSignal);
  r.connections.tablet.c1.lastSeen+=10000; r.players.phone.nickname='renamed';
  r.game={public:{revision:99}}; refreshCleanupSignal(r);
  assert.deepEqual(r.cleanupSignal,first);
  r.connections.tablet.c1.connected=false; refreshCleanupSignal(r);
  assert.equal(r.cleanupSignal.revision,first.revision+1);
  const terminal={roomInstanceId:r.roomInstanceId,allocationGeneration:1,status:'terminal',cleanupPending:true,terminalAt:now};
  refreshCleanupSignal(terminal,r.cleanupSignal);
  assert.equal(terminal.cleanupSignal.revision,first.revision+2);
  terminal.cleanupPending=false;refreshCleanupSignal(terminal);
  assert.equal(terminal.cleanupSignal,undefined,'completed terminal marker remains minimal');
});
test('room root wrapper writes a signal atomically and leaves unrelated refs alone', async t => {
  const db=setup(t); db.put('rooms/ABCDE',room());
  await runPrimedTransaction(db.ref('rooms/ABCDE'), raw=>({...raw,status:'playing'}));
  assert.equal(db.value('rooms/ABCDE/cleanupSignal/revision'),1);
  await runPrimedTransaction(db.ref('roomCreateRequests/a/op'),()=>({...room()}));
  assert.equal(db.value('roomCreateRequests/a/op/cleanupSignal'),null);
});
test('P1 scheduler retry sees current-only reconnect and preserves membership', async t => {
  const db=setup(t),r=room(); r.connections.phone.p1.connected=false;
  r.connections.phone.p1.lastSeen=1; db.put('rooms/ABCDE',r);
  db.beforeTransaction=path=>{if(path==='rooms/ABCDE') db.put('rooms/ABCDE/connections/phone/p1',{...r.connections.phone.p1,connected:true,lastSeen:now});};
  await cleanupGhostRoomPlayers.run({});
  assert.equal(db.value('rooms/ABCDE/players/phone/membershipId'),'member-1');
});
test('P1 due root CAS sees only a new controller heartbeat and defers the old job', async t => {
  const db=setup(t),r=room(); r.connections.tablet.c1.lastSeen=1;
  db.put('rooms/ABCDE',r);
  db.beforeTransaction=path=>{if(path==='rooms/ABCDE') db.put('rooms/ABCDE/connections/tablet/c1/lastSeen',now);};
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(db.value('rooms/ABCDE/status'),'waiting');
  assert.equal(db.value('roomCleanupQueue/ABCDE/nextCheckAt'),now+180000);
});
test('signal handler reads only signal, preserves backoff and rejects older revision', async t => {
  const db=setup(t),r=room(); refreshCleanupSignal(r);db.put('rooms/ABCDE',r);
  await syncRoomCleanupQueue.run({params:{roomCode:'ABCDE'}});
  assert.deepEqual(db.reads,['rooms/ABCDE/cleanupSignal']);
  db.put('roomCleanupQueue/ABCDE',{...db.value('roomCleanupQueue/ABCDE'),signalRevision:10,failures:2,nextCheckAt:now+900000});
  await syncRoomCleanupQueue.run({params:{roomCode:'ABCDE'}});
  assert.equal(db.value('roomCleanupQueue/ABCDE/signalRevision'),10);
  assert.equal(db.value('roomCleanupQueue/ABCDE/nextCheckAt'),now+900000);
});
test('B1 rejects old APK and preserves allocation replay fingerprint across transport capability', () => {
  const r=room();r.presenceProtocol=2;
  assert.throws(()=>assertRoomTarget(r,r.roomInstanceId), /업데이트/);
  const input={uid:'phone',role:'player',operationId:'connect-operation',roomInstanceId:r.roomInstanceId,membershipId:'member-1',expectedConnectionSeq:1,connectionId:'new-connection',now,presenceProtocol:2};
  const first=allocateRoomConnection(r,input);
  assert.deepEqual(allocateRoomConnection(r,{...input,connectionId:'late',now:now+10}),first);
  assert.equal(r.players.phone.currentConnectionId,'new-connection');
});
test('B1 controller stale compares canonical tuple/time, keeps strict >20s and ignores frozen summary', () => {
  const r=room();r.presenceProtocol=2;
  assert.equal(reportStaleController(r,now,now+20000,'c1',1).status,'notStale');
  assert.equal(reportStaleController(r,now,now+20001,'old',1).status,'staleContext');
  assert.equal(reportStaleController(r,now,now+20001,'c1',1).status,'disconnected');
  assert.equal(r.connections.tablet.c1.lastSeen,now);
});

test('B1 first pause preserves last canonical heartbeat timer rather than stale summary or detection time', () => {
  const r=room();r.presenceProtocol=2;r.status='playing';
  r.game={public:{status:'playing',gameType:'liars_poker',phase:'playing',revision:1,
    gameInstanceId:'game-one',phaseSeq:1,turnSeq:1,dataSeq:1,resumeEpoch:0,
    turnDeadlineAt:now+10000,players:{phone:{status:'alive'}}},private:{},server:{}};
  assert.equal(reportStaleController(r,now,now+21001,'c1',1).status,'disconnected');
  assert.equal(r.game.server.recovery.timer.remainingMs,10000);
  assert.equal(r.game.public.turnDeadlineAt,null);
});
test('cursor repair projects a missed false event using latest root identity/time', async t => {
  const db=setup(t),r=room();r.presenceProtocol=2;
  r.players.phone.isConnected=true;r.players.phone.lastSeen=1;
  r.connections.phone.p1.connected=false;
  db.put('rooms/ABCDE',r);
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(db.value('rooms/ABCDE/players/phone/isConnected'),false);
  assert.equal(db.value('rooms/ABCDE/players/phone/lastSeen'),now);
  assert.equal(db.value('rooms/ABCDE/status'),'waiting');
});
