import assert from 'node:assert/strict';
import {fork, spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {readFile, writeFile} from 'node:fs/promises';
import {setTimeout as delay} from 'node:timers/promises';
import {fileURLToPath} from 'node:url';
import test, {after, before} from 'node:test';

const project = 'demo-mosigame-e13';
process.chdir(fileURLToPath(new URL('../../', import.meta.url)));
assert.equal(process.env.GCLOUD_PROJECT, project);
for (const [key, host] of Object.entries({FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIREBASE_DATABASE_EMULATOR_HOST: '127.0.0.1:9000', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080'})) {
  assert.equal(process.env[key], host, `Missing local ${key}`);
}
const require = createRequire(new URL('../../functions/package.json', import.meta.url));
const firebaseConfig = JSON.parse(process.env.FIREBASE_CONFIG || '{}');
process.env.FIREBASE_CONFIG = JSON.stringify({...firebaseConfig, projectId: project,
  databaseURL: `https://${project}-default-rtdb.firebaseio.com`});
const functions = require('./lib/index.js');
const {getDatabase} = require('firebase-admin/database');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {deleteApp, getApp} = require('firebase-admin/app');
const db = getDatabase();
const firestore = getFirestore();
const workers = new Set();
const rooms = [];
const results = [];
let sequence = 0;
let operation = 0;
const id = () => `e13-operation-${++operation}`;
const context = pub => Object.fromEntries(['gameInstanceId', 'phaseSeq', 'turnSeq', 'dataSeq',
  'resumeEpoch'].map(key => [key, pub[key]]));

function scenario(name, fn) {
  test(name, {timeout: 90000}, async () => {
    const started = Date.now();
    try { await fn(); results.push({name, status: 'PASS', durationMs: Date.now() - started}); }
    catch (error) { results.push({name, status: 'FAIL', durationMs: Date.now() - started}); throw error; }
  });
}

async function callable(person, name, data) {
  const response = await fetch(`http://127.0.0.1:5001/${project}/asia-northeast3/${name}`, {
    method: 'POST', headers: {'Content-Type': 'application/json',
      ...(person ? {Authorization: `Bearer ${person.token}`} : {})},
    body: JSON.stringify({data}), signal: AbortSignal.timeout(15000)});
  const body = await response.json();
  if (body.error) throw Object.assign(new Error(`${name}: ${body.error.status}`), {code: body.error.status});
  assert.equal(response.ok, true, `${name}: HTTP failure`);
  return body.result;
}

async function denied(fn, codes = ['PERMISSION_DENIED']) {
  await assert.rejects(fn, error => codes.includes(error.code));
}

async function account(uid, nickname) {
  const email = `${uid}@example.invalid`;
  const password = 'LocalE13SyntheticOnly123!';
  await getAuth().createUser({uid, email, password});
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=e13-demo', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email, password, returnSecureToken: true}), signal: AbortSignal.timeout(10000)});
  assert.equal(response.ok, true, 'Synthetic authentication failed');
  const {idToken} = await response.json();
  await firestore.collection('users').doc(uid).set({nickname, ownedGames: []});
  await firestore.collection('userOnboarding').doc(uid).set({status: 'complete'});
  return {uid, nickname, token: idToken};
}

async function fixture(playerCount = 2) {
  const seq = ++sequence;
  const controller = await account(`e13-controller-${seq}`, `Tablet${seq}`);
  const creationOperation = id();
  const created = await callable(controller, 'createRealtimeRoom', {operationId: creationOperation});
  assert.equal(created.success, true);
  const target = {roomCode: created.roomCode, roomInstanceId: created.roomInstanceId};
  rooms.push(created.roomCode);
  const controllerContext = {...target, ...created, role: 'controller'};
  const players = [];
  const characters = ['frog', 'cat', 'bear', 'rabbit', 'bee', 'owl'];
  for (let index = 0; index < playerCount; index++) {
    const person = await account(`e13-player-${seq}-${index}`, `P${seq}x${index}`);
    const joined = await callable(person, 'joinRealtimeRoom', {...target, nickname: person.nickname,
      characterId: characters[index], operationId: id(), expectedConnectionSeq: 0});
    assert.equal(joined.success, true);
    person.session = {...target, ...joined, role: 'player'};
    players.push(person);
  }
  return {controller, controllerContext, creationOperation, players, target,
    ref: db.ref(`rooms/${created.roomCode}`)};
}

async function until(ref, predicate, label) {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const value = (await ref.get()).val();
    if (predicate(value)) return value;
    await delay(100);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

async function sdk(person) {
  const child = fork(fileURLToPath(new URL('./client.cjs', import.meta.url)), [],
    {stdio: ['ignore', 'ignore', 'ignore', 'ipc'], windowsHide: true});
  workers.add(child);
  let counter = 0;
  const pending = new Map();
  const events = new Map();
  child.on('message', message => {
    if (message.event) { events.get(message.event)?.push(message); return; }
    const task = pending.get(message.id);
    if (!task) return;
    pending.delete(message.id);
    clearTimeout(task.timer);
    if (message.error) task.reject(Object.assign(new Error('Client SDK rejected operation'), {code: message.error}));
    else task.resolve(message.result);
  });
  child.once('exit', () => {
    workers.delete(child);
    for (const task of pending.values()) {
      clearTimeout(task.timer); task.reject(new Error('Client SDK exited'));
    }
    pending.clear();
  });
  const request = (action, payload = {}) => new Promise((resolve, reject) => {
    const reqId = ++counter;
    const timer = setTimeout(() => { pending.delete(reqId); reject(new Error(`Client SDK ${action} timeout`)); }, 10000);
    if (action === 'watch') events.set(reqId, payload.events);
    pending.set(reqId, {resolve, reject, timer});
    child.send({id: reqId, action, payload: {...payload, events: undefined}});
  });
  await request('init', {token: person.token, name: person.uid});
  return {request, stop: async () => {
    if (child.exitCode !== null) return;
    await request('offline');
    await new Promise(resolve => { child.once('exit', resolve); child.kill(); });
  }};
}

async function start(f, game) {
  await callable(f.controller, 'selectRealtimeRoomGame', {...f.controllerContext, gameId: game});
  await callable(f.controller, 'beginRealtimeRoomSeating', f.controllerContext);
  await callable(f.controller, 'saveRealtimePlayerSeatIndexes', {...f.controllerContext,
    seatIndexesByUid: Object.fromEntries(f.players.map((player, index) => [player.uid, index]))});
  const request = {...f.controllerContext, commandId: id()};
  await callable(f.controller, `game_${game}_start_game`, request);
  await until(f.ref, room => room.status === 'playing', 'game status trigger');
  for (const person of f.players) await report(f, person, 'ready', 1);
  await report(f, f.controller, 'ready', 1);
  assert.equal((await f.ref.child('game/public/recovery/paused').get()).val(), false);
  return request;
}

async function report(f, person, state = 'ready', reportSeq = 1) {
  const room = (await f.ref.get()).val();
  return callable(person, 'game_common_recovery_report', {
    ...(person === f.controller ? f.controllerContext : person.session), ...context(room.game.public),
    state, screenUsable: true, assetsReady: true, reportSeq, commandId: id()});
}

before(async () => {
  for (const game of ['liars_poker', 'final_call', 'mafia', 'holdem']) {
    await firestore.collection('games').doc(game).set({enabled: true, accessType: 'free',
      minPlayers: game === 'mafia' || game === 'final_call' ? 4 : 2, maxPlayers: 12});
  }
});

after(async () => {
  for (const worker of workers) worker.kill();
  await writeFile('build/e13/backend-result.json', JSON.stringify({project, results,
    status: results.every(result => result.status === 'PASS') ? 'PASS' : 'FAIL'}, null, 2));
  await firestore.terminate();
  await deleteApp(getApp());
});

scenario('V21: production export manifest and isolated emulator region adapter', async () => {
  assert.equal(Object.keys(functions).length, 79);
  const triggers = Object.values(functions).filter(fn => fn.__endpoint?.eventTrigger?.eventType?.includes('database'));
  assert.equal(triggers.length, 5);
  for (const fn of triggers) assert.deepEqual(fn.__endpoint.region, ['asia-southeast1']);
  const rulesResponse = await fetch(`http://127.0.0.1:9000/.settings/rules.json?ns=${project}-default-rtdb`, {
    headers: {Authorization: 'Bearer owner'}, signal: AbortSignal.timeout(10000)});
  assert.equal(rulesResponse.ok, true, 'Local rules namespace must be configured');
  const rules = await rulesResponse.json();
  assert.deepEqual(rules, JSON.parse(await readFile('database.rules.json', 'utf8')));
  for (const [emulator, projectId] of [['false', project], ['true', 'not-the-demo']]) {
    const run = spawnSync(process.execPath, ['-e', 'require("./build/e13-runtime/index.cjs")'], {
      env: {...process.env, FUNCTIONS_EMULATOR: emulator, GCLOUD_PROJECT: projectId}, stdio: 'ignore'});
    assert.notEqual(run.status, 0, 'Test adapter must refuse non-emulator or non-demo discovery');
  }
});

scenario('V09/V20: concurrent room creation replay and reservation-only recovery', async () => {
  const f = await fixture();
  const replay = await Promise.all([0, 1].map(() => callable(f.controller, 'createRealtimeRoom', {
    operationId: f.creationOperation})));
  for (const result of replay) assert.equal(result.roomInstanceId === f.target.roomInstanceId, true);
  const person = await account('e13-reserved-controller', 'Reserved');
  const operationId = id();
  const reservation = {roomCode: 'ZZZZZ', roomInstanceId: 'e13-reserved-room',
    expectedAllocationGeneration: 0, allocationGeneration: 1,
    controllerSessionId: '11111111-1111-4111-8111-111111111111',
    connectionId: 'e13-reserved-connection', createdAt: Date.now(), status: 'reserved'};
  await db.ref(`roomCreateSlots/${person.uid}`).set({operationId, status: 'reserved'});
  await db.ref(`roomCreateRequests/${person.uid}/${operationId}`).set(reservation);
  const result = await callable(person, 'createRealtimeRoom', {operationId});
  rooms.push('ZZZZZ');
  assert.equal(result.roomInstanceId === reservation.roomInstanceId, true);
  assert.equal((await db.ref(`controllerRooms/${person.uid}/roomInstanceId`).get()).val() === reservation.roomInstanceId, true);
  await denied(() => callable(null, 'createRealtimeRoom', {operationId: id()}), ['UNAUTHENTICATED']);
});

scenario('V11: SDK subscription/onDisconnect and stale connection CAS protection', async () => {
  const f = await fixture();
  const player = f.players[0];
  const client = await sdk(player);
  const path = `rooms/${f.target.roomCode}/connections/${player.uid}/${player.session.connectionId}`;
  const events = [];
  await client.request('watch', {path: `rooms/${f.target.roomCode}/players`, events});
  await client.request('disconnect', {path: `${path}/connected`, value: false});
  await client.request('offline');
  await until(f.ref.child(`players/${player.uid}`), p => p?.isConnected === false, 'onDisconnect presence trigger');
  await client.request('online');
  await client.request('set', {path: `${path}/connected`, value: true});
  await until(f.ref.child(`players/${player.uid}`), p => p?.isConnected === true, 'reconnected presence trigger');
  const deadline = Date.now() + 10000;
  while (!events.some(event => event.value?.[player.uid]?.isConnected === true) && Date.now() < deadline) await delay(100);
  assert.equal(events.some(event => event.value?.[player.uid]?.isConnected === true), true, 'SDK subscription resumes');
  const previous = {...player.session};
  const request = {...previous, nickname: player.nickname, characterId: 'frog',
    expectedConnectionSeq: previous.connectionSeq, operationId: id()};
  const next = await callable(player, 'joinRealtimeRoom', request);
  assert.equal(next.connectionSeq, previous.connectionSeq + 1);
  const replay = await callable(player, 'joinRealtimeRoom', request);
  assert.equal(replay.connectionId === next.connectionId, true);
  await denied(() => callable(player, 'joinRealtimeRoom', {...request, operationId: id()}), ['ABORTED']);
  await denied(() => client.request('set', {path: `${path}/connected`, value: false}), ['PERMISSION_DENIED']);
  // A late event already in flight is distinct from a new, denied client write.
  await f.ref.child(`connections/${player.uid}/${previous.connectionId}/connected`).set(false);
  await delay(500);
  const current = (await f.ref.child(`players/${player.uid}`).get()).val();
  assert.equal(current.currentConnectionId === next.connectionId, true);
  assert.equal(current.isConnected, true);
  await client.stop();
});

for (const game of ['liars_poker', 'final_call', 'mafia', 'holdem']) {
  scenario(`V03/V04/V08/V09/V18/V21: ${game} callable, private rules, pause/barrier and replay`, async () => {
    const f = await fixture(game === 'final_call' || game === 'mafia' ? 4 : 2);
    const startRequest = await start(f, game);
    const initial = (await f.ref.get()).val();
    await callable(f.controller, `game_${game}_start_game`, startRequest);
    assert.equal((await f.ref.child('game/public/gameInstanceId').get()).val() === initial.game.public.gameInstanceId, true);
    await denied(() => callable(f.controller, `game_${game}_start_game`, {...startRequest, restart: true}));
    const progression = `game_${game}_${game === 'mafia' ? 'complete_role_reveal' : 'complete_dealing'}`;
    const progressRequest = {...f.controllerContext, ...context(initial.game.public), commandId: id()};
    const response = await callable(f.controller, progression, progressRequest);
    assert.equal(response.success, true);
    const progressed = (await f.ref.get()).val();
    const dataSeq = progressed.game.public.dataSeq;
    await callable(f.controller, progression, progressRequest);
    assert.equal((await f.ref.child('game/public/dataSeq').get()).val(), dataSeq);
    await denied(() => callable(f.controller, progression, {...progressRequest, commandId: id(), phaseSeq: -1}), ['FAILED_PRECONDITION']);
    const player = f.players[0];
    const client = await sdk(player);
    const base = `rooms/${f.target.roomCode}/game`;
    const publicEvents = [];
    const privateEvents = [];
    await client.request('watch', {path: `${base}/public`, events: publicEvents});
    await client.request('watch', {path: `${base}/private/${player.uid}`, events: privateEvents});
    const own = await client.request('get', {path: `${base}/private/${player.uid}`});
    assert.equal(own?._context?.dataSeq, dataSeq);
    assert.equal(publicEvents.some(event => event.value?.dataSeq === dataSeq), true);
    assert.equal(privateEvents.some(event => event.value?._context?.dataSeq === dataSeq), true);
    await denied(() => client.request('get', {path: `${base}/private/${f.players[1].uid}`}), ['PERMISSION_DENIED']);
    await denied(() => client.request('get', {path: `${base}/server`}), ['PERMISSION_DENIED']);
    await denied(() => client.request('set', {path: `${base}/public/revision`, value: 999}), ['PERMISSION_DENIED']);
    for (const person of f.players) {
      const privateContext = progressed.game.private?.[person.uid]?._context;
      assert.equal(privateContext?.dataSeq, dataSeq, 'Every required private context follows the public mutation');
    }
    const first = await report(f, player, 'failed', 2);
    assert.equal(first.status, 'accepted');
    assert.equal((await report(f, player, 'ready', 1)).status, 'ignored');
    const paused = (await f.ref.get()).val();
    const savedTimer = paused.game.server.recovery.timer;
    await report(f, f.players[1], 'failed', 2);
    assert.equal(JSON.stringify((await f.ref.child('game/server/recovery/timer').get()).val()) === JSON.stringify(savedTimer), true);
    await denied(() => callable(f.controller, progression, {...f.controllerContext,
      ...context(paused.game.public), commandId: id()}), ['FAILED_PRECONDITION']);
    for (const person of f.players) {
      await report(f, person, 'ready', 3);
      assert.equal((await f.ref.child('game/public/recovery/paused').get()).val(), true);
    }
    await report(f, f.controller, 'ready', 2);
    assert.equal((await f.ref.child('game/public/recovery/paused').get()).val(), false);
    await client.stop();
    const current = (await f.ref.get()).val();
    await callable(f.controller, `game_${game}_end_game`, {...f.controllerContext,
      ...context(current.game.public), commandId: id()});
    await until(f.ref, room => room.status === 'finished', 'finished game status trigger');
    assert.equal((await f.ref.child('game/server/recovery').get()).exists(), false);
  });
}

scenario('V06/V07/V21: actual disconnect triggers, scheduler expiration and one extension', async () => {
  const f = await fixture(3);
  await start(f, 'holdem');
  const player = f.players[0];
  const client = await sdk(player);
  const path = `rooms/${f.target.roomCode}/connections/${player.uid}/${player.session.connectionId}/connected`;
  await client.request('disconnect', {path, value: false});
  await client.request('offline');
  const paused = await until(f.ref, room => room?.game?.public?.recovery?.causes?.[`player:${player.uid}`], 'phone disconnect cause');
  const cause = paused.game.public.recovery.causes[`player:${player.uid}`];
  await f.ref.child(`game/public/recovery/causes/player:${player.uid}/deadlineAt`).set(Date.now() - 1);
  await functions.cleanupExpiredGameInterruptions.run({});
  assert.equal((await f.ref.child(`game/public/recovery/causes/player:${player.uid}/awaitingDecision`).get()).val(), true);
  assert.equal((await f.ref.child(`players/${player.uid}`).get()).exists(), true);
  const data = {...f.controllerContext, ...context(paused.game.public), incidentId: cause.incidentId,
    playerUid: player.uid, commandId: id()};
  const extended = await callable(f.controller, 'game_common_interruption_wait_more', data);
  assert.equal(extended.status, 'extended');
  assert.equal((await callable(f.controller, 'game_common_interruption_wait_more', data)).deadlineAt, extended.deadlineAt);
  assert.equal((await callable(f.controller, 'game_common_interruption_wait_more', {...data, commandId: id()})).status, 'notAllowed');
  await denied(() => callable(f.players[1], 'game_common_interruption_wait_more', {
    ...f.players[1].session, ...context(paused.game.public), incidentId: cause.incidentId,
    playerUid: player.uid, commandId: id()}));
  const excluded = await callable(f.controller, 'game_common_interruption_exclude_player', {
    ...f.controllerContext, ...context(paused.game.public), incidentId: cause.incidentId,
    pauseId: paused.game.public.recovery.pauseId, playerUid: player.uid, commandId: id()});
  assert.equal(excluded.status, 'excluded');
  assert.equal((await f.ref.child(`players/${player.uid}`).get()).exists(), false);
  assert.equal((await f.ref.child('game/public/status').get()).val(), 'playing');
  const controller = await sdk(f.controller);
  await controller.request('set', {path: `rooms/${f.target.roomCode}/connections/${f.controller.uid}/${f.controllerContext.connectionId}/connected`, value: false});
  await until(f.ref, room => room?.game?.public?.recovery?.causes?.[`controller:${f.controller.uid}`], 'controller disconnect cause');
  await client.stop();
  await controller.stop();
});

scenario('V10/V19: leave result replay, rejoin protection and membership entitlements', async () => {
  const f = await fixture();
  const player = f.players[0];
  await firestore.collection('users').doc(player.uid).update({ownedGames: ['holdem']});
  const outsider = await account('e13-outsider', 'Outside');
  const query = f.target;
  const group = await callable(player, 'fetchRealtimeRoomGroupEntitlements', query);
  assert.equal(group.status, 'current');
  assert.deepEqual(group.ownedGameIds, ['holdem']);
  await denied(() => callable(outsider, 'fetchRealtimeRoomGroupEntitlements', query));
  const leave = {...player.session, operationId: id()};
  await callable(player, 'leaveRealtimeRoom', leave); // Discard the response as if transport lost it.
  const status = await callable(player, 'game_common_operation_status', leave);
  assert.equal(status.status, 'applied');
  assert.equal((await f.ref.child(`players/${player.uid}`).get()).exists(), false);
  const rejoined = await callable(player, 'joinRealtimeRoom', {...f.target, nickname: player.nickname,
    characterId: 'frog', expectedConnectionSeq: 0, operationId: id()});
  assert.equal(rejoined.membershipId === player.session.membershipId, false);
  await callable(player, 'leaveRealtimeRoom', leave);
  assert.equal((await f.ref.child(`players/${player.uid}/membershipId`).get()).val() === rejoined.membershipId, true);
  assert.equal((await callable(player, 'leaveRealtimeRoom', {...leave, operationId: id()})).status, 'stale');
  assert.equal((await f.ref.child(`players/${player.uid}/membershipId`).get()).val() === rejoined.membershipId, true);
  await denied(() => callable(player, 'fetchRealtimeRoomGroupEntitlements', {...query, roomInstanceId: 'e13-old-room'}), ['FAILED_PRECONDITION']);
});

scenario('V20/V21: cleanup queue trigger, terminal reconciliation and stale generation protection', async () => {
  const f = await fixture();
  const queued = await until(db.ref(`roomCleanupQueue/${f.target.roomCode}`), job => job?.roomInstanceId === f.target.roomInstanceId, 'cleanup queue trigger');
  assert.equal(queued.allocationGeneration, 1);
  // New allocation wins against a queued delete for an old generation.
  const newInstance = 'e13-reused-room-instance';
  await f.ref.update({roomInstanceId: newInstance, allocationGeneration: 2});
  await delay(500);
  await db.ref(`roomCleanupQueue/${f.target.roomCode}`).set({...queued, nextCheckAt: 0});
  // Seed >500 terminal prefixes to force the persistent scan beyond its first page.
  const terminal = Object.fromEntries(Array.from({length: 505}, (_, index) =>
    [`0${String(index).padStart(4, '0')}`, {status: 'terminal', roomInstanceId: `e13-terminal-${index}`,
      allocationGeneration: 1, cleanupPending: false, terminalAt: 1}]));
  // Tombstones are pre-existing fixtures, not 505 simultaneous lifecycle events.
  // Suppress background dispatch only while seeding them, restore it before
  // the real scheduler/cursor checks and all live-room trigger assertions.
  const disabled = await fetch('http://127.0.0.1:4400/functions/disableBackgroundTriggers', {method: 'PUT'});
  assert.equal(disabled.ok, true);
  try { await db.ref('rooms').update(terminal); }
  finally {
    const enabled = await fetch('http://127.0.0.1:4400/functions/enableBackgroundTriggers', {method: 'PUT'});
    assert.equal(enabled.ok, true);
  }
  for (let iteration = 0; iteration < 6; iteration++) await functions.cleanupStaleRealtimeRooms.run({});
  assert.equal((await f.ref.child('roomInstanceId').get()).val() === newInstance, true);
  assert.equal((await f.ref.child('status').get()).val(), 'waiting');
  const closeFixture = await fixture();
  await callable(closeFixture.controller, 'closeRoom', {...closeFixture.controllerContext, operationId: id()});
  await closeFixture.ref.update({cleanupAt: Date.now() - 1});
  await until(db.ref(`roomCleanupQueue/${closeFixture.target.roomCode}`), job => job?.nextCheckAt <= Date.now(), 'closed room due queue');
  await functions.cleanupStaleRealtimeRooms.run({});
  const closed = (await closeFixture.ref.get()).val();
  assert.equal(closed.status, 'terminal');
  assert.equal(closed.cleanupPending, false);
  assert.equal((await db.ref(`controllerRooms/${closeFixture.controller.uid}`).get()).exists(), false);
  assert.equal((await db.ref(`roomCreateRequests/${closeFixture.controller.uid}/${closeFixture.creationOperation}/status`).get()).val(), 'terminal');
});
