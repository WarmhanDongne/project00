import assert from 'node:assert/strict';
import test from 'node:test';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const {logger} = require('firebase-functions');
const {HttpsError} = require('firebase-functions/v2/https');
const {traceRoomAction} = require('../lib/room/room-action-timing.js');

test('timing preserves result and records only fixed labels and durations', async t => {
  const logs = [];
  t.mock.method(logger, 'info', (...args) => logs.push(args));
  const secretResult = {roomCode: 'private-room', uid: 'private-user'};
  assert.equal(await traceRoomAction('createRealtimeRoom', async timer => {
    await timer.measure('room_read', async () => secretResult);
    return timer.measure('room_read', async () => secretResult);
  }), secretResult);
  assert.equal(logs.length, 1);
  const [event, record] = logs[0];
  assert.equal(event, 'room_action_timing');
  assert.equal(record.status, 'success');
  assert.equal(record.stages.room_read.count, 2);
  assert.equal(record.stages.room_read.failures, 0);
  assert.ok(record.durationMs >= 0);
  assert.ok(!JSON.stringify(logs).includes('private-'));
});

test('timing preserves original error and excludes error message/details', async t => {
  const logs = [];
  t.mock.method(logger, 'info', (...args) => logs.push(args));
  const error = new HttpsError('failed-precondition', 'private-message', {token: 'private-token'});
  await assert.rejects(traceRoomAction('closeRoom', timer => timer.measure('close_transaction', async () => {
    throw error;
  })), value => value === error);
  const record = logs[0][1];
  assert.equal(record.errorCode, 'failed-precondition');
  assert.equal(record.status, 'failure');
  assert.equal(record.stages.close_transaction.failures, 1);
  assert.ok(!JSON.stringify(logs).includes('private-'));
});

test('a failed log sink cannot turn an applied command into a failure', async t => {
  t.mock.method(logger, 'info', () => { throw Error('sink unavailable'); });
  assert.equal(await traceRoomAction('closeRoom', async () => 'applied'), 'applied');
});
