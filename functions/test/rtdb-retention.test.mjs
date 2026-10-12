import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';
import {CleanupDatabase} from './fake-cleanup-database.mjs';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin/database');
const {logger} = require('firebase-functions');
const {cleanupGhostRoomPlayers} = require('../lib/game-interruption/expire-scheduler.js');
const {refreshCleanupSignal} = require('../lib/room/cleanup-signal.js');
const {cleanupStaleRealtimeRooms, reconcileTerminal, syncRoomCleanupQueue} = require('../lib/room/room-cleanup.js');
const {createRealtimeRoom} = require('../lib/room/create-room.js');
const onboarding = require('../lib/auth/require-complete-onboarding.js');
const NOW = 10_000_000;

function setup(t) {
  const database = new CleanupDatabase();
  const logs = [];
  t.mock.method(admin, 'getDatabase', () => database);
  t.mock.method(logger, 'info', (message, counters) => logs.push({message, counters}));
  t.mock.method(Date, 'now', () => NOW);
  return {database, logs};
}
function room(overrides = {}) {
  return {roomInstanceId: 'original-room', allocationGeneration: 1, status: 'waiting',
    controllerUid: 'tablet-user', membershipRevision: 4, controllerCurrentConnectionId: 'tablet-current',
    players: {'phone-user': {status: 'active', role: 'player', membershipId: 'phone-member',
      currentConnectionId: 'phone-current', connectionSeq: 1, isConnected: false, lastSeen: NOW - 300_001}},
    connections: {'tablet-user': {'tablet-current': {connected: true}},
      'phone-user': {'phone-current': {connected: false}}}, sessionOperations: {saved: {result: {status: 'applied'}}},
    ...overrides};
}
function terminalRecords(database, status = 'created') {
  const target = {roomInstanceId: 'original-room', allocationGeneration: 1, status: 'terminal',
    controllerUid: 'tablet-user', creationOperationId: 'create-operation', terminalAt: NOW, cleanupPending: true};
  database.put('rooms/ABCDE', target);
  database.put('roomCreateRequests/tablet-user/create-operation', {...target, status, roomCode: 'ABCDE',
    expectedAllocationGeneration: 0, createdAt: NOW - 60_000,
    controllerSessionId: 'private-controller-session', connectionId: 'private-connection'});
  database.put('roomCreateSlots/tablet-user', {...target, operationId: 'create-operation', status});
  return target;
}

test('ghost scan reaches rooms after 500 terminal prefixes, then wraps without touching connections or ledger', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 500; n++) database.put('rooms/A' + String(n).padStart(4, '0'), {status: 'terminal'});
  const original = room();
  database.put('rooms/Z9999', original);
  await cleanupGhostRoomPlayers.run({});
  assert.ok(database.value('rooms/Z9999/players/phone-user'));
  assert.equal(database.value('roomCleanupScan/ghostCursor'), 'A0499');
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('rooms/Z9999/players/phone-user'), null);
  assert.equal(database.value('rooms/Z9999/membershipRevision'), 5);
  assert.deepEqual(database.value('rooms/Z9999/connections'), original.connections);
  assert.deepEqual(database.value('rooms/Z9999/sessionOperations'), original.sessionOperations);
  assert.equal(database.value('roomCleanupScan/ghostCursor'), null);
  assert.equal(logs.at(-1).counters.removed, 1);
  assert.ok(database.limits.every(query => query.value <= 501));
});

for (const transition of ['reconnect', 'start-game', 'new-allocation']) {
  test('ghost cleanup rechecks current state after ' + transition, async t => {
    const {database} = setup(t);
    database.put('rooms/ABCDE', room());
    database.beforeTransaction = path => {
      if (path !== 'rooms/ABCDE') return;
      database.beforeTransaction = null;
      const latest = database.value(path);
      if (transition === 'reconnect') {
        latest.players['phone-user'].isConnected = true;
        latest.players['phone-user'].lastSeen = NOW;
      } else if (transition === 'start-game') latest.game = {public: {status: 'playing'}};
      else {
        latest.roomInstanceId = 'new-room'; latest.allocationGeneration++;
        latest.players['phone-user'].lastSeen = NOW;
      }
      database.put(path, latest);
    };
    await cleanupGhostRoomPlayers.run({});
    assert.ok(database.value('rooms/ABCDE/players/phone-user'));
    assert.equal(database.value('rooms/ABCDE/membershipRevision'), 4);
  });
}

test('a failed ghost transaction does not starve the tail and is retried after wrap', async t => {
  const {database, logs} = setup(t);
  database.put('rooms/A0000', room());
  for (let n = 1; n < 500; n++) database.put('rooms/A' + String(n).padStart(4, '0'), {status: 'terminal'});
  database.put('rooms/Z9999', room());
  database.failures.add('rooms/A0000');
  await cleanupGhostRoomPlayers.run({});
  assert.equal(logs.at(-1).counters.failed, 1);
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('rooms/Z9999/players/phone-user'), null);
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('rooms/A0000/players/phone-user'), null);
});

test('cursor removal and inserted keys are covered after the next wrap', async t => {
  const {database} = setup(t);
  database.put('roomCleanupScan/ghostCursor', 'M0000');
  database.put('rooms/A0000', room());
  database.put('rooms/Z9999', room());
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('rooms/Z9999/players/phone-user'), null);
  assert.ok(database.value('rooms/A0000/players/phone-user'));
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('rooms/A0000/players/phone-user'), null);
});

test('an overlapping scan cannot overwrite another run cursor and logs only aggregate counts', async t => {
  const {database, logs} = setup(t);
  database.put('rooms/ABCDE', room());
  database.beforeTransaction = path => {
    if (path === 'roomCleanupScan/ghostCursor') database.put(path, 'ZZZZZ');
  };
  await cleanupGhostRoomPlayers.run({});
  assert.equal(database.value('roomCleanupScan/ghostCursor'), 'ZZZZZ');
  assert.equal(logs.at(-1).counters.cursorAdvanced, false);
  assert.ok(!JSON.stringify(logs).includes('phone-user'));
  assert.ok(!JSON.stringify(logs).includes('ABCDE'));
});

test('ghost transactions are bounded and callback retries do not double-count removal', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 25; n++) database.put('rooms/A' + String(n).padStart(4, '0'), room());
  database.rerunTransaction = () => {};
  await cleanupGhostRoomPlayers.run({});
  assert.ok(database.maxActive <= 10);
  assert.equal(logs.at(-1).counters.removed, 25);
});

test('confirmed terminal requests are compact, replay remains terminal, and generations survive', async t => {
  const {database} = setup(t);
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  const target = terminalRecords(database);
  await reconcileTerminal('ABCDE', target);
  assert.deepEqual(database.value('roomCreateRequests/tablet-user/create-operation'), {
    roomCode: 'ABCDE', roomInstanceId: 'original-room', allocationGeneration: 1,
    status: 'terminal', createdAt: NOW - 60_000});
  await reconcileTerminal('ABCDE', target);
  assert.deepEqual(await createRealtimeRoom.run({auth: {uid: 'tablet-user'},
    data: {presenceProtocol:2, operationId: 'create-operation'}}), {status: 'terminal'});
  assert.equal(database.value('rooms/ABCDE/allocationGeneration'), 1);
  assert.equal(database.value('rooms/ABCDE/cleanupPending'), false);
});

test('a compact old request still replays terminal after another creation replaces its slot', async t => {
  const {database} = setup(t);
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  const target = terminalRecords(database);
  await reconcileTerminal('ABCDE', target);
  database.put('roomCreateSlots/tablet-user', {operationId: 'other-operation', status: 'terminal'});
  const before = database.value('rooms');
  assert.deepEqual(await createRealtimeRoom.run({auth: {uid: 'tablet-user'},
    data: {presenceProtocol:2, operationId: 'create-operation'}}), {status: 'terminal'});
  assert.deepEqual(database.value('rooms'), before);
});

test('reserved records and unproven terminal allocations retain their original fields', async t => {
  const {database} = setup(t);
  const target = terminalRecords(database, 'reserved');
  await reconcileTerminal('ABCDE', target);
  assert.equal(database.value('roomCreateRequests/tablet-user/create-operation/controllerSessionId'), 'private-controller-session');
  const closed = terminalRecords(database);
  database.put('rooms/ABCDE/status', 'closed');
  await reconcileTerminal('ABCDE', closed);
  assert.equal(database.value('roomCreateRequests/tablet-user/create-operation/connectionId'), 'private-connection');
});

test('old reconciliation preserves a replacement room, mapping, and slot', async t => {
  const {database} = setup(t);
  const old = terminalRecords(database);
  const replacement = {...room(), roomInstanceId: 'replacement-room', allocationGeneration: 2};
  database.put('rooms/ABCDE', replacement);
  const mapping = {roomCode: 'ABCDE', ...replacement};
  database.put('controllerRooms/tablet-user', mapping);
  database.put('roomCreateSlots/tablet-user', {...replacement, operationId: 'new-operation'});
  await reconcileTerminal('ABCDE', old);
  assert.deepEqual(database.value('rooms/ABCDE'), replacement);
  assert.deepEqual(database.value('controllerRooms/tablet-user'), mapping);
  assert.equal(database.value('roomCreateSlots/tablet-user/operationId'), 'new-operation');
});

test('partial reconciliation retains the pending marker and finishes safely on retry', async t => {
  const {database} = setup(t);
  const target = terminalRecords(database);
  database.failures.add('roomCreateSlots/tablet-user');
  await assert.rejects(reconcileTerminal('ABCDE', target));
  assert.equal(database.value('rooms/ABCDE/cleanupPending'), true);
  await reconcileTerminal('ABCDE', target);
  assert.equal(database.value('rooms/ABCDE/cleanupPending'), false);
  assert.equal(database.value('roomCreateRequests/tablet-user/create-operation/status'), 'terminal');
});

test('room cleanup distinguishes stale jobs from reconciliations and reports queue bounds without payload', async t => {
  const {database, logs} = setup(t);
  const target = terminalRecords(database);
  database.put('roomCleanupQueue/ABCDE', {...target, nextCheckAt: NOW - 1000, failures: 0});
  database.put('roomCleanupQueue/Z9999', {roomInstanceId: 'absent', allocationGeneration: 1, nextCheckAt: NOW - 5000});
  await cleanupStaleRealtimeRooms.run({});
  const counters = logs.at(-1).counters;
  assert.equal(counters.completed, 2);
  assert.equal(counters.staleJobs, 1);
  assert.equal(counters.terminalReconciliations, 1);
  assert.equal(counters.failed, 0);
  assert.equal(counters.scanned, 1);
  assert.equal(counters.queueLimitReached, false);
  assert.equal(counters.oldestDueAgeMs, 5000);
  assert.ok(!JSON.stringify(logs).includes('private-controller-session'));
});

test('room cleanup failure retries with backoff and does not lose terminal state', async t => {
  const {database, logs} = setup(t);
  const target = terminalRecords(database);
  database.put('roomCleanupQueue/ABCDE', {...target, nextCheckAt: NOW - 1000, failures: 0});
  database.failures.add('roomCreateSlots/tablet-user');
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.failed, 1);
  assert.equal(database.value('rooms/ABCDE/cleanupPending'), true);
  assert.equal(database.value('roomCleanupQueue/ABCDE/failures'), 1);
  assert.equal(database.value('roomCleanupQueue/ABCDE/nextCheckAt'), NOW + 60_000);
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.failed, 0);
  assert.equal(logs.at(-1).counters.completed, 0);
  assert.equal(database.value('roomCleanupQueue/ABCDE/nextCheckAt'), NOW + 60_000);
  t.mock.method(Date, 'now', () => NOW + 60_001);
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(database.value('rooms/ABCDE/cleanupPending'), false);
  assert.equal(database.value('roomCleanupQueue/ABCDE'), null);
});

test('cleanup preserves a failed job backoff across trigger refreshes and resets it only for a new allocation', async t => {
  const {database} = setup(t);
  const target = terminalRecords(database);
  database.put('roomCleanupQueue/ABCDE', {...target, failures: 2, nextCheckAt: NOW + 120_000});
  database.put('rooms/ABCDE', refreshCleanupSignal(database.value('rooms/ABCDE')));
  await syncRoomCleanupQueue.run({params: {roomCode: 'ABCDE'}});
  assert.equal(database.value('roomCleanupQueue/ABCDE/nextCheckAt'), NOW + 120_000);
  database.put('rooms/ABCDE', {...room(), allocationGeneration: 2, roomInstanceId: 'replacement',
    controllerPresence: {lastSeen: NOW}});
  database.put('rooms/ABCDE', refreshCleanupSignal(database.value('rooms/ABCDE')));
  await syncRoomCleanupQueue.run({params: {roomCode: 'ABCDE'}});
  assert.equal(database.value('roomCleanupQueue/ABCDE/failures'), 0);
  assert.equal(database.value('roomCleanupQueue/ABCDE/nextCheckAt'), NOW + 180_000);
});

test('room scans process 100 records without counting the lookahead and cover the remainder', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 101; n++) database.put('rooms/A' + String(n).padStart(4, '0'),
    {roomInstanceId: 'terminal-' + n, allocationGeneration: 1, status: 'terminal', cleanupPending: false});
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.scanned, 100);
  assert.equal(database.value('roomCleanupScan/cursor'), 'A0099');
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.scanned, 1);
  assert.equal(database.value('roomCleanupScan/cursor'), null);
});

test('due cleanup queue processes at most 300 jobs and signals its cap without an unbounded query', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 301; n++) database.put('roomCleanupQueue/A' + String(n).padStart(4, '0'),
    {roomInstanceId: 'absent-' + n, allocationGeneration: 1, nextCheckAt: NOW - 1000});
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.completed, 300);
  assert.equal(logs.at(-1).counters.queueLimitReached, true);
  assert.equal(Object.keys(database.value('roomCleanupQueue')).length, 1);
  await cleanupStaleRealtimeRooms.run({});
  assert.equal(logs.at(-1).counters.completed, 1);
  assert.equal(logs.at(-1).counters.queueLimitReached, false);
});
