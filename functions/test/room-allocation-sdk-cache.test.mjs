import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const adminDatabase = require('firebase-admin/database');
const onboarding = require('../lib/auth/require-complete-onboarding.js');
const {createRealtimeRoom} = require('../lib/room/create-room.js');
const {closeRoom, removeRealtimeRoomPlayer} = require('../lib/room/realtime-room-lifecycle.js');
const {cleanupStaleRealtimeRooms, reconcileTerminal} = require('../lib/room/room-cleanup.js');

function snapshot(value) {
  return {val: () => structuredClone(value), exists: () => value != null, child: key => snapshot(value?.[key] ?? null),
    forEach(callback) { for (const [key, child] of Object.entries(value ?? {})) callback({...snapshot(child), key}); }};
}

class ColdCacheDatabase {
  values = new Map();
  starts = [];
  reads = [];
  subscriptions = [];
  removals = [];
  transactions = [];
  activeListeners = 0;
  abortTransactions = new Set();
  ref(path) {
    const database = this;
    let listeners = 0;
    return {
      async get() {
        database.reads.push(path);
        await database.beforeGet?.(path);
        return snapshot(database.values.get(path) ?? null);
      },
      on(_event, listener) {
        listeners++; database.activeListeners++; database.subscriptions.push(path);
        listener(snapshot(database.values.get(path) ?? null));
      },
      off() { listeners--; database.activeListeners--; database.removals.push(path); },
      async set(value) { database.values.set(path, structuredClone(value)); },
      async transaction(update) {
        database.transactions.push(path);
        database.beforeTransaction?.(path);
        const server = database.values.get(path) ?? null;
        // get() does not populate the persistent cache. SDK aborts a cold
        // callback returning undefined before reading the server at all.
        const cached = server && typeof server === 'object' ? Object.fromEntries(Object.entries(server).reverse()) : server;
        let next = update(listeners ? structuredClone(cached) : null);
        if (next === undefined) return {committed: false, snapshot: snapshot(server)};
        if (database.abortTransactions.has(path)) return {committed: false, snapshot: snapshot(server)};
        if (database.rerunTransaction) {
          database.rerunTransaction(path);
          next = update(structuredClone(database.values.get(path) ?? null));
        }
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

function deferred() {
  let resolve;
  const promise = new Promise(yes => { resolve = yes; });
  return {promise, resolve};
}

function lifecycleRoom() {
  return {roomInstanceId: 'room-instance', allocationGeneration: 1, presenceProtocol: 2,
    controllerUid: 'test-controller', controllerSessionId: '12345678-1234-4123-8123-123456789abc',
    status: 'waiting', membershipRevision: 4,
    players: {'test-phone': {membershipId: 'phone-member', role: 'player', status: 'active'}}};
}

function lifecycleRequest(overrides = {}) {
  return {auth: {uid: 'test-controller'}, data: {roomCode: 'ABCDE', roomInstanceId: 'room-instance',
    presenceProtocol: 2, controllerSessionId: '12345678-1234-4123-8123-123456789abc',
    operationId: 'close-operation', playerUid: 'test-phone', ...overrides}};
}

function setup(t) {
  const database = new ColdCacheDatabase();
  t.mock.method(adminDatabase, 'getDatabase', () => database);
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  return database;
}

test('creation starts onboarding and mapping reads together and waits for both before writing', async t => {
  const database = setup(t);
  const onboardingReady = deferred();
  const mappingReady = deferred();
  let onboardingStarted = false;
  t.mock.method(onboarding, 'assertOnboardingComplete', () => {
    onboardingStarted = true;
    return onboardingReady.promise;
  });
  database.beforeGet = path => path === 'controllerRooms/test-controller' ? mappingReady.promise : undefined;
  const creating = createRealtimeRoom.run({auth: {uid: 'test-controller'},
    data: {presenceProtocol: 2, operationId: 'create-operation'}});
  assert.equal(onboardingStarted, true);
  assert.deepEqual(database.reads, ['controllerRooms/test-controller']);
  assert.equal(database.values.size, 0);
  assert.deepEqual(database.transactions, []);
  onboardingReady.resolve();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(database.transactions, [], 'mapping must settle before creation writes');
  mappingReady.resolve();
  assert.equal((await creating).success, true);
  assert.equal(database.activeListeners, 0);
});

for (const failingPrerequisite of ['onboarding', 'operation', 'mapping']) {
  test('creation preserves prerequisite error priority for ' + failingPrerequisite, async t => {
    const database = setup(t);
    const onboardingError = new Error('onboarding unavailable');
    const mappingError = new Error('mapping unavailable');
    t.mock.method(onboarding, 'assertOnboardingComplete', async () => {
      if (failingPrerequisite === 'onboarding') throw onboardingError;
    });
    database.beforeGet = async () => { throw mappingError; };
    await assert.rejects(createRealtimeRoom.run({auth: {uid: 'test-controller'},
      data: {presenceProtocol: 2, operationId: failingPrerequisite === 'mapping' ? 'create-operation' : 'bad'}}),
    error => failingPrerequisite === 'onboarding' ? error === onboardingError :
      failingPrerequisite === 'operation' ? error.code === 'invalid-argument' : error === mappingError);
    assert.deepEqual(database.transactions, []);
    assert.equal(database.values.size, 0);
    assert.equal(database.activeListeners, 0);
  });
}

for (const failingPrerequisite of ['onboarding', 'operation', 'mapping']) {
  test('synchronous database initialization failure preserves ' + failingPrerequisite + ' error priority', async t => {
    const database = setup(t);
    const onboardingReady = deferred();
    const onboardingError = new Error('onboarding denied');
    const databaseError = new Error('database initialization unavailable');
    const unhandled = [];
    const captureUnhandled = error => unhandled.push(error);
    process.on('unhandledRejection', captureUnhandled);
    t.after(() => process.off('unhandledRejection', captureUnhandled));
    t.after(() => onboardingReady.resolve());
    let onboardingStarted = false;
    let initializationCalls = 0;
    t.mock.method(onboarding, 'assertOnboardingComplete', async () => {
      onboardingStarted = true;
      await onboardingReady.promise;
      if (failingPrerequisite === 'onboarding') throw onboardingError;
    });
    t.mock.method(adminDatabase, 'getDatabase', () => {
      initializationCalls++;
      throw databaseError;
    });
    const creating = createRealtimeRoom.run({auth: {uid: 'test-controller'},
      data: {presenceProtocol: 2, operationId: failingPrerequisite === 'mapping' ? 'create-operation' : 'bad'}});
    const outcome = assert.rejects(creating, error =>
      failingPrerequisite === 'onboarding' ? error === onboardingError :
        failingPrerequisite === 'operation' ? error.code === 'invalid-argument' : error === databaseError);
    assert.equal(onboardingStarted, true);
    assert.equal(initializationCalls, 1);
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(unhandled, [], 'SDK initialization rejection must be handled while onboarding is pending');
    onboardingReady.resolve();
    await outcome;
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(unhandled, []);
    assert.deepEqual(database.transactions, []);
    assert.deepEqual(database.reads, []);
    assert.equal(database.values.size, 0);
  });
}

for (const [name, command] of [['close', closeRoom], ['kick', removeRealtimeRoomPlayer]]) {
  test(name + ' uses one priming listener, no preliminary get, and releases it', async t => {
    const database = setup(t);
    database.values.set('rooms/ABCDE', lifecycleRoom());
    assert.equal((await command.run(lifecycleRequest())).success, true);
    assert.deepEqual(database.reads, []);
    assert.deepEqual(database.subscriptions, ['rooms/ABCDE']);
    assert.deepEqual(database.removals, ['rooms/ABCDE']);
    assert.equal(database.activeListeners, 0);
    const committed = structuredClone(database.values.get('rooms/ABCDE'));
    await command.run(lifecycleRequest());
    assert.deepEqual(database.values.get('rooms/ABCDE'), committed, 'replay must preserve revision and retention');
  });

  test(name + ' returns not-found for a primed absent room and releases the listener', async t => {
    const database = setup(t);
    await assert.rejects(command.run(lifecycleRequest()), error => error.code === 'not-found');
    assert.deepEqual(database.reads, []);
    assert.deepEqual(database.removals, ['rooms/ABCDE']);
    assert.equal(database.activeListeners, 0);
  });

  test(name + ' cannot report success after a transaction aborts', async t => {
    const database = setup(t);
    const original = lifecycleRoom();
    database.values.set('rooms/ABCDE', original);
    database.abortTransactions.add('rooms/ABCDE');
    await assert.rejects(command.run(lifecycleRequest()), error => error.code === 'aborted');
    assert.deepEqual(database.values.get('rooms/ABCDE'), original);
    assert.equal(database.activeListeners, 0);
  });

  test(name + ' cannot report success when the primed room disappears before mutation', async t => {
    const database = setup(t);
    database.values.set('rooms/ABCDE', lifecycleRoom());
    database.beforeTransaction = path => database.values.delete(path);
    await assert.rejects(command.run(lifecycleRequest()), error => error.code === 'not-found');
    assert.equal(database.values.has('rooms/ABCDE'), false);
    assert.equal(database.activeListeners, 0);
  });

  for (const changedContext of ['controller', 'room', 'protocol']) {
    test(name + ' rejects a changed ' + changedContext + ' during transaction rerun', async t => {
      const database = setup(t);
      database.values.set('rooms/ABCDE', lifecycleRoom());
      database.rerunTransaction = path => {
        const current = database.values.get(path);
        if (changedContext === 'controller') current.controllerSessionId = '12345678-1234-4123-8123-123456789abd';
        if (changedContext === 'room') current.roomInstanceId = 'room-replacement';
        if (changedContext === 'protocol') current.presenceProtocol = 2;
      };
      // A legacy initial room accepts an older request; a rerun upgraded to B1 must reject it.
      if (changedContext === 'protocol') database.values.get('rooms/ABCDE').presenceProtocol = 1;
      const request = lifecycleRequest(changedContext === 'protocol' ? {presenceProtocol: 1} : {});
      await assert.rejects(command.run(request), error => error.code ===
        (changedContext === 'controller' ? 'permission-denied' : 'failed-precondition'));
      assert.equal(database.values.get('rooms/ABCDE').status, 'waiting');
      assert.ok(database.values.get('rooms/ABCDE').players['test-phone']);
      assert.equal(database.values.get('rooms/ABCDE').membershipRevision, 4);
      assert.equal(database.activeListeners, 0);
    });
  }
}

test('lobby kick rechecks a game starting during transaction rerun', async t => {
  const database = setup(t);
  database.values.set('rooms/ABCDE', lifecycleRoom());
  database.rerunTransaction = path => {
    database.values.get(path).game = {public: {status: 'playing'}};
  };
  await assert.rejects(removeRealtimeRoomPlayer.run(lifecycleRequest()), error => error.code === 'failed-precondition');
  assert.ok(database.values.get('rooms/ABCDE').players['test-phone']);
  assert.equal(database.values.get('rooms/ABCDE').membershipRevision, 4);
  assert.equal(database.activeListeners, 0);
});

test('cold RTDB cache keeps same creation operation live and finalizes its reservation and slot', async t => {
  const database = setup(t);
  const request = {auth: {uid: 'test-controller'}, data: {presenceProtocol:2, operationId: 'create-operation'}};
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
  const first = await createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-first'}});
  const closeRequest = {auth, data: {...first, operationId: 'close-first'}};
  await closeRoom.run(closeRequest);
  const closed = structuredClone(database.values.get(`rooms/${first.roomCode}`));
  assert.equal(closed.status, 'closed');
  const second = await createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-second'}});
  assert.equal(second.success, true);
  assert.notEqual(second.roomInstanceId, first.roomInstanceId);
  assert.equal(database.values.get(`rooms/${first.roomCode}`).status, 'closed', 'retention is unchanged');
  const replacement = structuredClone(database.values.get('controllerRooms/test-controller'));
  await closeRoom.run(closeRequest);
  await assert.rejects(createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-first'}}),
    error => error.code === 'failed-precondition');
  await reconcileTerminal(first.roomCode, {...closed, status: 'terminal'});
  assert.deepEqual(database.values.get('controllerRooms/test-controller'), replacement);
  assert.equal(database.values.get('roomCreateSlots/test-controller').operationId, 'create-second');
  assert.equal(database.values.get(`rooms/${second.roomCode}`).status, 'waiting');
});

test('closed-room proof cannot replace an unrelated pending slot or another generation', async t => {
  const database = setup(t);
  const auth = {uid: 'test-controller'};
  const first = await createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-first'}});
  await closeRoom.run({auth, data: {...first, operationId: 'close-first'}});
  const original = structuredClone(database.values.get('roomCreateSlots/test-controller'));
  for (const slot of [
    {...original, operationId: 'unknown-pending', status: 'reserved'},
    {...original, allocationGeneration: original.allocationGeneration + 1},
    {...original, roomInstanceId: 'another-instance'},
  ]) {
    database.values.set('roomCreateSlots/test-controller', slot);
    await assert.rejects(createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-second'}}),
      error => error.code === 'failed-precondition' && error.details?.reason === 'creationPending');
    assert.deepEqual(database.values.get('roomCreateSlots/test-controller'), slot);
  }
});

test('two concurrent replacements of a closed room allocate only one live room', async t => {
  const database = setup(t);
  const auth = {uid: 'test-controller'};
  const first = await createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId: 'create-first'}});
  await closeRoom.run({auth, data: {...first, operationId: 'close-first'}});
  const results = await Promise.allSettled(['create-next-a', 'create-next-b'].map(operationId =>
    createRealtimeRoom.run({auth, data: {presenceProtocol:2, operationId}})));
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
