import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const database = require('firebase-admin/database');
const onboarding = require('../lib/auth/require-complete-onboarding.js');
const {game_liars_poker_start_game: start} = require('../lib/liars-poker/start-game.js');
const {restartRound} = require('../lib/liars-poker/restart-round.js');
const {excludeLiarsPokerPlayer} = require('../lib/liars-poker/exclude-player.js');
const {previewRecoveryExclusion, decorateRecoveryCauses} = require('../lib/game-interruption/game-adapters.js');
const {registerRecoveryFailure} = require('../lib/game-interruption/recovery-state.js');
const {leaveSessionRequest} = require('../lib/game-interruption/leave-request.js');
const {resumeRealtimeControllerRoom: resume} = require('../lib/room/realtime-room-lifecycle.js');
const {joinRealtimeRoom: join} = require('../lib/room/realtime-room-functions.js');
const {game_common_recovery_report: report, game_common_interruption_expire: expire,
  game_common_interruption_on_connection_changed: presence} =
  require('../lib/game-interruption/functions.js');

// RTDB does not preserve nulls or empty maps. Every committed write/read uses
// this representation; JSON serialization alone would retain the missing map.
function stored(value) {
  if (value == null) return null;
  if (typeof value !== 'object') return value;
  const entries = Object.entries(value).map(([k, v]) => [k, stored(v)]).filter(([, v]) => v !== null);
  return entries.length ? Object.fromEntries(entries) : null;
}

class RoomRef {
  constructor(count) {
    this.value = {roomInstanceId: 'room-current', status: 'seating', selectedGame: 'liars_poker',
      controllerUid: 'tablet', controllerSessionId: '11111111-1111-4111-8111-111111111111',
      controllerCurrentConnectionId: 'connection-tablet', controllerConnectionSeq: 1,
      connections: {tablet: {'connection-tablet': {roomInstanceId: 'room-current',
        connectionSeq: 1, connected: true, lastSeen: 1}}}, players: {}};
    for (let i = 0; i < count; i++) {
      const uid = `player${i}`;
      this.value.players[uid] = {uid, role: 'player', status: 'active', seatIndex: i,
        membershipId: `membership-${uid}`, nickname: uid, characterId: ['frog', 'bear', 'cat'][i],
        currentConnectionId: `connection-${uid}`, connectionSeq: 1, isConnected: true, lastSeen: 1};
      this.value.connections[uid] = {[`connection-${uid}`]: {roomInstanceId: 'room-current',
        membershipId: `membership-${uid}`, connectionSeq: 1, connected: true, lastSeen: 1}};
    }
  }
  snapshot() { return {val: () => structuredClone(this.value), exists: () => this.value !== null}; }
  async get() { return this.snapshot(); }
  on(_event, listener) { listener(this.snapshot()); }
  off() {}
  async transaction(update) {
    const next = update(structuredClone(this.value));
    if (next === undefined) return {committed: false, snapshot: this.snapshot()};
    this.value = stored(next);
    return {committed: true, snapshot: this.snapshot()};
  }
  request(id, uid = 'tablet', extra = {}) {
    const player = this.value.players?.[uid];
    const pub = this.value.game?.public ?? {};
    return {auth: {uid}, data: {roomCode: 'ABCDE', roomInstanceId: this.value.roomInstanceId,
      role: player ? 'player' : 'controller', controllerSessionId: this.value.controllerSessionId,
      membershipId: player?.membershipId,
      connectionId: player?.currentConnectionId ?? this.value.controllerCurrentConnectionId,
      connectionSeq: player?.connectionSeq ?? this.value.controllerConnectionSeq,
      ...Object.fromEntries(['gameInstanceId', 'phaseSeq', 'turnSeq', 'dataSeq', 'resumeEpoch']
        .filter(k => pub[k] !== undefined).map(k => [k, pub[k]])),
      commandId: id, operationId: id, ...extra}};
  }
}

async function setup(t, count = 3) {
  const ref = new RoomRef(count);
  t.mock.method(database, 'getDatabase', () => ({ref: path => {
    assert.equal(path, 'rooms/ABCDE'); return ref;
  }}));
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  await start.run(ref.request('start-operation'));
  assert.equal(ref.value.game.public.phase, 'dealing');
  assert.equal(ref.value.game.private, undefined, 'real start empty private is absent after read-back');
  registerRecoveryFailure(ref.value, 'player0', 'player', Date.now(), 'disconnected');
  ref.value = stored(ref.value);
  return ref;
}

for (const nextRound of [false, true]) {
  test(`LP ${nextRound ? 'next round' : 'first deal'} read-back supports exclusion and a non-mutating preview`, async t => {
    const ref = await setup(t);
    if (nextRound) {
      restartRound(ref.value.game, 'player1', Date.now());
      ref.value = stored(ref.value);
    }
    const before = structuredClone(ref.value);
    const preview = previewRecoveryExclusion(ref.value, 'player0', Date.now());
    assert.equal(preview.canContinue, true);
    assert.deepEqual(ref.value, before);
    decorateRecoveryCauses(ref.value, Date.now());
    assert.equal(ref.value.game.public.recovery.causes['player:player0'].canContinue, true);
    excludeLiarsPokerPlayer(ref.value.game, 'player0', Date.now());
    assert.equal(ref.value.game.public.players.player0.status, 'eliminated');
    assert.equal(ref.value.game.server.pendingHands.player0, undefined);
    assert.equal(Object.keys(ref.value.game.server.pendingHands).length, 2);
    assert.equal(ref.value.game.public.phase, 'dealing');
  });
}

test('dealing self-leave removes membership once and ends when only one survivor remains', async t => {
  const ref = await setup(t, 2);
  const request = ref.request('leave-operation', 'player0');
  const first = await leaveSessionRequest(request);
  assert.equal(first.status, 'applied');
  assert.equal(ref.value.players.player0, undefined);
  assert.equal(ref.value.game.public.status, 'finished');
  assert.equal(ref.value.game.public.finishReason, 'insufficientPlayers');
  const saved = structuredClone(ref.value);
  assert.deepEqual(await leaveSessionRequest(request), first);
  assert.deepEqual(ref.value, saved, 'replayed leave does not mutate again');
});

for (const operation of ['resume', 'join', 'report', 'ready', 'expire', 'presence']) {
  test(`LP dealing ${operation} commits despite absent private and existing player recovery cause`, async t => {
    const ref = await setup(t);
    let response;
    if (operation === 'resume') {
      response = await resume.run(ref.request('resume-operation', 'tablet', {expectedConnectionSeq: 1}));
      assert.equal(response.connectionSeq, 2);
      assert.equal(ref.value.controllerCurrentConnectionId, response.connectionId);
    } else if (operation === 'join') {
      response = await join.run(ref.request('join-operation', 'player1', {
        expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', reconnectOnly: true,
      }));
      assert.equal(response.connectionSeq, 2);
      assert.equal(ref.value.players.player1.currentConnectionId, response.connectionId);
    } else if (operation === 'report' || operation === 'ready') {
      response = await report.run(ref.request('report-operation', 'player1', {
        state: operation === 'ready' ? 'ready' : 'failed', reportSeq: 1,
        screenUsable: operation === 'ready', assetsReady: operation === 'ready',
      }));
      assert.ok(response.status);
    } else if (operation === 'presence') {
      ref.value.players.player1.isConnected = false;
      await presence.run({params: {roomCode: 'ABCDE', uid: 'player1'},
        data: {after: {val: () => false}}});
      assert.ok(ref.value.game.public.recovery.causes['player:player1']);
    } else {
      const cause = ref.value.game.public.recovery.causes['player:player0'];
      cause.deadlineAt = Date.now() - 1;
      response = await expire.run(ref.request('expire-operation', 'tablet', {incidentId: cause.incidentId}));
      assert.equal(response.status, 'awaitingDecision');
    }
    assert.equal(ref.value.game.public.recovery.paused, true, 'transport success never replaces ready barrier');
    assert.equal(ref.value.game.public.recovery.causes['player:player0'].canContinue, true);
    assert.equal(ref.value.game.private, undefined);
  });
}
