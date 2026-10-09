import assert from 'node:assert/strict';
import test from 'node:test';
import {runGameCommandTransaction} from '../lib/game-interruption/game-command-transaction.js';
import {gameRandomInt,gameRandomUUID} from '../lib/common/transaction-random.js';
const session='11111111-1111-4111-8111-111111111111';
function fixture(type='holdem'){
 return {roomInstanceId:'room-current',controllerUid:'tablet',controllerSessionId:session,status:'playing',
  controllerCurrentConnectionId:'connection-current',controllerConnectionSeq:1,
  connections:{tablet:{'connection-current':{roomInstanceId:'room-current',connectionSeq:1,connected:true,lastSeen:1}}},players:{},
  game:{public:{gameType:type,gameInstanceId:'game-current',phaseSeq:1,turnSeq:1,dataSeq:1,resumeEpoch:0,
   phase:'playing',startedAt:1,status:'playing',revision:1,updatedAt:1,turnDeadlineAt:10000,players:{}},private:{},server:{}}};
}
function request(extra={}){return {auth:{uid:'tablet'},data:{roomCode:'ABCDE',roomInstanceId:'room-current',
 role:'controller',controllerSessionId:session,connectionId:'connection-current',connectionSeq:1,
 commandId:'command-original',gameInstanceId:'game-current',phaseSeq:1,turnSeq:1,dataSeq:1,resumeEpoch:0,...extra}};}
class Ref{
 constructor(value,retries=1){this.value=value;this.retries=retries;}
 on(_event,callback){callback({val:()=>this.value});}
 off(){}
 async transaction(update){
  let next;for(let attempt=0;attempt<this.retries;attempt++)next=update(structuredClone(this.value));
  if(next===undefined)return {committed:false,snapshot:{val:()=>this.value}};
  this.value=next;return {committed:true,snapshot:{val:()=>this.value}};
 }
}
for(const type of ['liars_poker','final_call','mafia','holdem'])test(`${type} rejects old game/phase/turn and paused progress before mutation`,async()=>{
 const ref=new Ref(fixture(type));let mutations=0;
 const update=raw=>{mutations++;return raw;};
 for(const extra of [{gameInstanceId:'game-old'},{phaseSeq:0},{turnSeq:0},{connectionId:'connection-old'}]){
  await assert.rejects(()=>runGameCommandTransaction(ref,request(extra),`game_${type}_advance`,update));
 }
 ref.value.game.public.recovery={paused:true,pauseId:'pause-current',causes:{}};
 ref.value.game.server.recovery={remainingMs:5000,ready:{}};
 await assert.rejects(()=>runGameCommandTransaction(ref,request(),`game_${type}_advance`,update),/기기 준비/);
 assert.equal(mutations,0);assert.equal(ref.value.roomOperations,undefined);
 const ended=await runGameCommandTransaction(ref,request(),`game_${type}_end_game`,raw=>{
  raw.game.public.status='finished';return raw;
 });
 assert.equal(ended.committed,true);assert.equal(ref.value.game.public.recovery,undefined);
});
test('same operation replay returns original response before stale game checks and rejects changed domain/UID',async()=>{
 const ref=new Ref(fixture());let mutations=0;
 const response={success:true,result:'original'};
 await runGameCommandTransaction(ref,request(),'game_holdem_act',raw=>{
  mutations++;raw.game.public.phase='handResult';return raw;
 },()=>response);
 const replay=await runGameCommandTransaction(ref,request({connectionId:'connection-expired'}),'game_holdem_act',()=>{throw Error('must not execute');});
 assert.deepEqual(replay.operationResult,response);assert.equal(mutations,1);
 await assert.rejects(()=>runGameCommandTransaction(ref,request({amount:999}),'game_holdem_act',raw=>raw));
 const other=request();other.auth.uid='another';
 await assert.rejects(()=>runGameCommandTransaction(ref,other,'game_holdem_act',raw=>raw));
});
test('transaction callback retries use the same clock and rewind entropy, committing one response',async()=>{
 const ref=new Ref(fixture(),3),attempts=[];
 const result=await runGameCommandTransaction(ref,request(),'game_holdem_act',(raw,now)=>{
  const value={now,card:gameRandomInt(52),id:gameRandomUUID()};attempts.push(value);raw.game.public.result=value;return raw;
 },()=>({success:true}));
 assert.equal(result.committed,true);assert.equal(attempts.length,3);
 assert.deepEqual(attempts[0],attempts[1]);assert.deepEqual(attempts[1],attempts[2]);
 assert.equal(ref.value.game.public.dataSeq,2);
});
