import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const database = require('firebase-admin/database');
const games = ['liars_poker', 'final_call', 'mafia', 'holdem'].map(id => {
  const directory = id.replaceAll('_', '-');
  return {id, start: require(`../lib/${directory}/start-game.js`)[`game_${id}_start_game`],
    end: require(`../lib/${directory}/end-game.js`)[`game_${id}_end_game`]};
});
const {game_liars_poker_prepare_penalty: prepare, game_liars_poker_resolve_penalty: resolve} =
  require('../lib/liars-poker/finish-penalty.js');
const {applyWaitingGameSelection} = require('../lib/room/room-seating-policy.js');
const controllerSessionId = '11111111-1111-4111-8111-111111111111';

class RoomRef {
  constructor(id) {
    this.value = {roomInstanceId: 'room-current', status: 'seating', selectedGame: id,
      controllerUid: 'tablet', controllerSessionId,
      controllerCurrentConnectionId: 'connection-current', controllerConnectionSeq: 1,
      connections: {tablet: {'connection-current': {roomInstanceId: 'room-current',
        connectionSeq: 1, connected: true, lastSeen: 1}}},
      players: Object.fromEntries(Array.from({length: 6}, (_, seatIndex) => [
        `player${seatIndex}`, {role: 'player', status: 'active', seatIndex,
          membershipId: `membership${seatIndex}`, nickname: `Player ${seatIndex}`,
          characterId: 'frog', profileImageUrl: 'https://example.com/profile.png', lastSeen: 1},
      ]))};
    this.listeners = 0;
  }
  snapshot() { return {val: () => structuredClone(this.value)}; }
  async get() { return this.snapshot(); }
  on(event, callback) { assert.equal(event, 'value'); this.listeners++; callback(this.snapshot()); }
  off() { this.listeners--; }
  async transaction(update) {
    let next = update(structuredClone(this.value));
    if (this.conflict) {
      this.conflict(this.value);
      this.conflict = null;
      next = update(structuredClone(this.value));
    }
    if (next === undefined) return {committed: false, snapshot: this.snapshot()};
    this.value = structuredClone(next);
    return {committed: true, snapshot: this.snapshot()};
  }
  request(commandId, extra = {}) {
    const context = this.value.game?.public ?? {};
    return {auth: {uid: 'tablet'}, data: {roomCode: 'ABCDE', roomInstanceId: 'room-current',
      role: 'controller', controllerSessionId, connectionId: 'connection-current', connectionSeq: 1,
      ...Object.fromEntries(['gameInstanceId', 'phaseSeq', 'turnSeq', 'dataSeq', 'resumeEpoch']
        .filter(key => context[key] !== undefined).map(key => [key, context[key]])),
      commandId, ...extra}};
  }
}

function setup(t, id = 'liars_poker') {
  const ref = new RoomRef(id);
  t.mock.method(database, 'getDatabase', () => ({ref: path => {
    assert.equal(path, 'rooms/ABCDE'); return ref;
  }}));
  return ref;
}

async function penaltyRoom(t) {
  const ref = setup(t);
  await games[0].start.run(ref.request('start-operation'));
  delete ref.value.game.public.recovery;
  delete ref.value.game.server.recovery;
  ref.value.game.public.phase = 'penalty';
  ref.value.game.public.penaltyTargetUid = 'player0';
  return ref;
}

test('LP prepare→resolve uses separate IDs, replays lost responses and applies exactly once', async t => {
  const ref = await penaltyRoom(t);
  const drawRequest = ref.request('roulette-prepare');
  const drawn = await prepare.run(drawRequest);
  assert.deepEqual(await prepare.run(drawRequest), drawn);
  assert.deepEqual(await prepare.run(ref.request('roulette-prepare-again')), drawn,
    'a new prepare request must not redraw the current penalty');
  const finishRequest = ref.request('roulette-resolve', {resolutionId: drawn.resolutionId});
  const result = await resolve.run(finishRequest);
  const finished = structuredClone(ref.value);
  assert.equal(result.type, 'penaltyResolved');
  assert.equal(ref.value.game.server.pendingPenaltyResolution, undefined);
  assert.equal(ref.value.game.public.penaltyResult.result, drawn.result);
  assert.deepEqual(await resolve.run(finishRequest), result);
  assert.deepEqual(ref.value, finished, 'replay must not advance rounds or apply penalty twice');
});

test('LP rejects wrong resolution, shared kind ID and foreign UID without mutation', async t => {
  const ref = await penaltyRoom(t);
  const drawn = await prepare.run(ref.request('roulette-prepare'));
  const before = structuredClone(ref.value);
  await assert.rejects(resolve.run(ref.request('roulette-resolve', {resolutionId: 'wrong-resolution'})),
    error => error.code === 'failed-precondition');
  await assert.rejects(resolve.run(ref.request(drawn.resolutionId, {resolutionId: drawn.resolutionId})),
    error => error.code === 'permission-denied');
  const foreign = ref.request('roulette-foreign', {resolutionId: drawn.resolutionId});
  foreign.auth.uid = 'another-tablet';
  await assert.rejects(resolve.run(foreign), error => error.code === 'permission-denied');
  assert.deepEqual(ref.value, before);
});

for (const game of games) {
  test(`${game.id}: heartbeat contention, response replay, end→new start preserve game boundaries`, async t => {
    const ref = setup(t, game.id);
    ref.conflict = room => { room.players.player0.lastSeen = 2000; };
    const original = ref.request('start-operation');
    const result = await game.start.run(original);
    assert.equal(result.success, true);
    const firstId = ref.value.game.public.gameInstanceId;
    if (game.id === 'liars_poker') assert.ok(Object.values(ref.value.game.public.players).every(p => p.penaltyCount === 0));
    assert.deepEqual(await game.start.run(original), result);
    assert.equal(ref.value.game.public.gameInstanceId, firstId);
    // Mirrors the asynchronous status trigger for the three games that use it.
    ref.value.status = 'playing';
    await assert.rejects(game.start.run(ref.request('fresh-start-request')));
    assert.equal(ref.value.game.public.gameInstanceId, firstId);
    assert.equal((await game.end.run(ref.request('end-operation'))).success, true);
    assert.equal(ref.value.game.public.status, 'finished');
    ref.value.status = 'finished';
    applyWaitingGameSelection(ref.value, game.id);
    ref.value.status = 'seating';
    assert.equal((await game.start.run(ref.request('new-start-operation'))).success, true);
    assert.notEqual(ref.value.game.public.gameInstanceId, firstId);
    if (game.id === 'liars_poker') assert.ok(Object.values(ref.value.game.public.players).every(p => p.penaltyCount === 0), 'new games reset roulette attempts');
    assert.equal(ref.listeners, 0);
  });

  test(`${game.id}: actual seating change aborts and a corrected new attempt succeeds`, async t => {
    const ref = setup(t, game.id);
    ref.conflict = room => { room.players.player0.seatIndex = 7; };
    await assert.rejects(game.start.run(ref.request('changed-seats-start')),
      error => error.code === 'aborted');
    assert.equal(ref.value.game, undefined);
    assert.equal(ref.listeners, 0);
    ref.value.players.player0.seatIndex = 0;
    assert.equal((await game.start.run(ref.request('corrected-start'))).success, true);
  });
}

const {game_common_recovery_report: readyReport} = require('../lib/game-interruption/functions.js');
const {registerRecoveryFailure} = require('../lib/game-interruption/recovery-state.js');

test('actual A/B/tablet ready rejects old connection and resumes only current confirmations', async t => {
  const ref = setup(t);
  ref.value.players = Object.fromEntries(Object.entries(ref.value.players).slice(0, 2));
  for (const [uid, player] of Object.entries(ref.value.players)) {
    player.currentConnectionId = `connection-${uid}`;
    player.connectionSeq = 1;
    ref.value.connections[uid] = {[player.currentConnectionId]: {roomInstanceId: 'room-current', membershipId: player.membershipId, connectionSeq: 1, connected: true, lastSeen: 1}};
  }
  await games[0].start.run(ref.request('concurrent-start'));
  const request = (uid, seq) => {
    const result = ref.request(`ready-${uid}-${seq}`, {reportSeq: seq, state: 'ready', screenUsable: true, assetsReady: true});
    if (uid !== 'tablet') {
      result.auth.uid = uid;
      Object.assign(result.data, {role: 'player', membershipId: ref.value.players[uid].membershipId, connectionId: ref.value.players[uid].currentConnectionId, connectionSeq: ref.value.players[uid].connectionSeq});
      delete result.data.controllerSessionId;
    }
    return result;
  };
  const responses = await Promise.all(['player0', 'player1', 'tablet'].map(uid => readyReport.run(request(uid, 1))));
  assert.ok(responses.every(r => r.status === 'accepted'));
  assert.equal(ref.value.game.public.recovery.paused, false);
  registerRecoveryFailure(ref.value, 'player0', 'player', Date.now());
  const old = request('player0', 2);
  ref.value.players.player0.currentConnectionId = 'new-connection';
  ref.value.players.player0.connectionSeq = 2;
  ref.value.connections.player0['new-connection'] = {roomInstanceId: 'room-current', membershipId: ref.value.players.player0.membershipId, connectionSeq: 2, connected: true, lastSeen: 1};
  await assert.rejects(readyReport.run(old), e => e.code === 'permission-denied' && e.details.reason === 'staleConnection');
  assert.equal(ref.value.game.public.recovery.paused, true);
  assert.equal((await readyReport.run(request('player0', 3))).status, 'accepted');
  assert.equal(ref.value.game.public.recovery.paused, true, 'other required participants still need ready');
  for (const uid of ['player1', 'tablet']) await readyReport.run(request(uid, 3));
  assert.equal(ref.value.game.public.recovery.paused, false);
  assert.equal(ref.listeners, 0);
});