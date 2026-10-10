import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const adminDatabase = require('firebase-admin/database');
const onboarding = require('../lib/auth/require-complete-onboarding.js');
const {createRealtimeRoom} = require('../lib/room/create-room.js');
const {closeRoom} = require('../lib/room/realtime-room-lifecycle.js');
const {cleanupStaleRealtimeRooms, reconcileTerminal} = require('../lib/room/room-cleanup.js');

function snapshot(value) {
  return {val: () => structuredClone(value), exists: () => value != null, child: key => snapshot(value?.[key] ?? null),
    forEach(callback) { for (const [key, child] of Object.entries(value ?? {})) callback({...snapshot(child), key}); }};
}

class ColdCacheDatabase {
  values = new Map();
  starts = [];
  ref(path) {
    const database = this;
    let listeners = 0;
    return {
      async get() { return snapshot(database.values.get(path) ?? null); },
      on(_event, listener) { listeners++; listener(snapshot(database.values.get(path) ?? null)); },
      off() { listeners--; },
      async set(value) { database.values.set(path, structuredClone(value)); },
      async transaction(update) {
        const server = database.values.get(path) ?? null;
        // get() does not populate the persistent cache. SDK aborts a cold
        // callback returning undefined before reading the server at all.
        const cached = server && typeof server === 'object' ? Object.fromEntries(Object.entries(server).reverse()) : server;
        let next = update(listeners ? structuredClone(cached) : null);
        if (next === undefined) return {committed: false, snapshot: snapshot(server)};
        if (!listeners && server !== null) next = update(structuredClone(server));
        if (next === undefined) return {committed: false, snapshot: snapshot(server)};
        database.values.set(path, structuredClone(next));
        return {committed: true, snapshot: snapshot(next)};
      },
      orderByKey() { return this; },
      orderByChild() { return this; },
      endAt() { return this; },
      startAt(value) {
        assert.notEqual(value, '', 'RTDB rejects an empty orderByKey query bound');
        database.starts.push(value); return this;
      },
      limitToFirst() { return this; },
    };
  }
}

function setup(t) {
  const database = new ColdCacheDatabase();
  t.mock.method(adminDatabase, 'getDatabase', () => database);
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  return database;
}

test('cold RTDB cache keeps same creation operation live and finalizes its reservation and slot', async t => {
  const database = setup(t);
  const request = {auth: {uid: 'test-controller'}, data: {operationId: 'create-operation'}};
  const first = await createRealtimeRoom.run(request);
  assert.equal(first.success, true);
  assert.equal(database.values.get('roomCreateRequests/test-controller/create-operation').status, 'created');
  assert.equal(database.values.get('roomCreateSlots/test-controller').status, 'created');
  const replay = await createRealtimeRoom.run(request);
  assert.equal(replay.roomInstanceId, first.roomInstanceId);
  assert.equal(database.values.get(`rooms/${first.roomCode}`).status, 'waiting');
});

test('create-close-create succeeds immediately, and old requests/cleanup preserve the new room', async t => {
  const database = setup(t);
  const auth = {uid: 'test-controller'};
  const first = await createRealtimeRoom.run({auth, data: {operationId: 'create-first'}});
  const closeRequest = {auth, data: {...first, operationId: 'close-first'}};
  await closeRoom.run(closeRequest);
  const closed = structuredClone(database.values.get(`rooms/${first.roomCode}`));
  assert.equal(closed.status, 'closed');
  const second = await createRealtimeRoom.run({auth, data: {operationId: 'create-second'}});
  assert.equal(second.success, true);
  assert.notEqual(second.roomInstanceId, first.roomInstanceId);
  assert.equal(database.values.get(`rooms/${first.roomCode}`).status, 'closed', 'retention is unchanged');
  const replacement = structuredClone(database.values.get('controllerRooms/test-controller'));
  await closeRoom.run(closeRequest);
  await assert.rejects(createRealtimeRoom.run({auth, data: {operationId: 'create-first'}}),
    error => error.code === 'failed-precondition');
  await reconcileTerminal(first.roomCode, {...closed, status: 'terminal'});
  assert.deepEqual(database.values.get('controllerRooms/test-controller'), replacement);
  assert.equal(database.values.get('roomCreateSlots/test-controller').operationId, 'create-second');
  assert.equal(database.values.get(`rooms/${second.roomCode}`).status, 'waiting');
});

test('closed-room proof cannot replace an unrelated pending slot or another generation', async t => {
  const database = setup(t);
  const auth = {uid: 'test-controller'};
  const first = await createRealtimeRoom.run({auth, data: {operationId: 'create-first'}});
  await closeRoom.run({auth, data: {...first, operationId: 'close-first'}});
  const original = structuredClone(database.values.get('roomCreateSlots/test-controller'));
  for (const slot of [
    {...original, operationId: 'unknown-pending', status: 'reserved'},
    {...original, allocationGeneration: original.allocationGeneration + 1},
    {...original, roomInstanceId: 'another-instance'},
  ]) {
    database.values.set('roomCreateSlots/test-controller', slot);
    await assert.rejects(createRealtimeRoom.run({auth, data: {operationId: 'create-second'}}),
      error => error.code === 'failed-precondition' && error.details?.reason === 'creationPending');
    assert.deepEqual(database.values.get('roomCreateSlots/test-controller'), slot);
  }
});

test('two concurrent replacements of a closed room allocate only one live room', async t => {
  const database = setup(t);
  const auth = {uid: 'test-controller'};
  const first = await createRealtimeRoom.run({auth, data: {operationId: 'create-first'}});
  await closeRoom.run({auth, data: {...first, operationId: 'close-first'}});
  const results = await Promise.allSettled(['create-next-a', 'create-next-b'].map(operationId =>
    createRealtimeRoom.run({auth, data: {operationId}})));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const rooms = [...database.values.entries()].filter(([path, room]) => path.startsWith('rooms/') && room.status === 'waiting');
  assert.equal(rooms.length, 1);
  assert.equal(database.values.get('controllerRooms/test-controller').roomInstanceId, rooms[0][1].roomInstanceId);
});

test('cold cache terminal reconciliation completes matching records and preserves a replacement mapping', async t => {
  const database = setup(t);
  const terminal = {roomInstanceId: 'room-original', allocationGeneration: 1, controllerUid: 'test-controller',
    creationOperationId: 'create-operation', status: 'terminal', terminalAt: 1000, cleanupPending: true};
  database.values.set('rooms/ABCDE', terminal);
  database.values.set('roomCreateRequests/test-controller/create-operation', {...terminal, status: 'created'});
  database.values.set('roomCreateSlots/test-controller', {...terminal, operationId: 'create-operation', status: 'created'});
  const replacement = {roomInstanceId: 'room-new', allocationGeneration: 2, roomCode: 'ABCDE'};
  database.values.set('controllerRooms/test-controller', replacement);
  await reconcileTerminal('ABCDE', terminal);
  assert.equal(database.values.get('roomCreateRequests/test-controller/create-operation').status, 'terminal');
  assert.equal(database.values.get('roomCreateSlots/test-controller').status, 'terminal');
  assert.deepEqual(database.values.get('controllerRooms/test-controller'), replacement);
  assert.equal(database.values.get('rooms/ABCDE').cleanupPending, false);
});

test('cleanup starts its first page without an empty SDK key bound and uses a saved cursor', async t => {
  const database = setup(t);
  await cleanupStaleRealtimeRooms.run({});
  assert.deepEqual(database.starts, []);
  database.values.set('roomCleanupScan/cursor', 'ABCDE');
  await cleanupStaleRealtimeRooms.run({});
  assert.deepEqual(database.starts, ['ABCDE']);
});
