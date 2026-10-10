import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import {runPrimedTransaction} from '../lib/room/room-transaction.js';

// Run the installed SDK's rerun/abort path. State access is isolated; no Firebase
// app, network, emulator, or production data is used by this harness.
const sdk = readFileSync(new URL('../node_modules/@firebase/database-compat/dist/index.standalone.js', import.meta.url), 'utf8');
const start = sdk.indexOf('function repoRerunTransactionQueue(');
const end = sdk.indexOf('\nfunction repoGetAncestorTransactionNode(', start);
assert.ok(start >= 0 && end > start);

test('SDK async rerun update error aborts, rolls back, cleans queue and returns original error', async () => {
  const original = new Error('changed roster during SDK rerun');
  const events = [];
  let activeListeners = 0;
  let callbacks = 0;
  const sandbox = {util: {assert: (value, message) => assert.ok(value, message)},
    newRelativePath: () => ({}), MAX_TRANSACTION_RETRIES: 25,
    repoGetLatestState: () => ({val: () => ({changed: true})}),
    syncTreeAckUserWrite: (_tree, id, revert) => { events.push(['rollback', id, revert]); return []; },
    eventQueueRaiseEventsForChangedPath: () => {},
    repoPruneCompletedTransactionsBelowNode: () => events.push(['prune']),
    repoSendReadyTransactions: () => events.push(['send-ready']),
    exceptionGuard: callback => callback(), setTimeout: callback => callback()};
  vm.runInNewContext(sdk.slice(start, end), sandbox);
  let transaction;
  const ref = {
    on: (_event, listener) => { activeListeners++; listener({val: () => ({changed: false})}); },
    off: () => { activeListeners--; },
    transaction: update => new Promise((resolve, reject) => {
      assert.deepEqual(update({changed: false}), {changed: false});
      transaction = {status: 0, retryCount: 1, currentWriteId: 7, path: '/fixture', update,
        unwatcher: () => events.push(['unwatch']),
        onComplete: (error, committed) => { callbacks++; error ? reject(error) : resolve({committed}); }};
      queueMicrotask(() => {
        try { sandbox.repoRerunTransactionQueue({}, [transaction], '/fixture'); }
        catch (error) { reject(error); } // Keep an unfixed regression bounded.
      });
    }),
  };
  await assert.rejects(runPrimedTransaction(ref, value => {
    if (value.changed) throw original;
    return value;
  }), error => error === original);
  assert.equal(callbacks, 1);
  assert.equal(transaction.status, 2);
  assert.deepEqual(events, [['rollback', 7, true], ['unwatch'], ['prune'], ['send-ready']]);
  assert.equal(activeListeners, 0);
  // Queue cleanup occurs before onComplete, so a later transaction can proceed.
  const next = await runPrimedTransaction({...ref, transaction: async update =>
    ({committed: update({ok: true}) !== undefined})}, value => value);
  assert.equal(next.committed, true);
});

test('first callback exception also aborts via SDK completion and releases listener', async () => {
  const original = new Error('initial update rejected');
  let completed = false;
  let removed = false;
  const ref = {on: (_event, listener) => listener({}), off: () => { removed = true; },
    transaction: async update => {
      assert.equal(update({}), undefined);
      completed = true;
      return {committed: false};
    }};
  await assert.rejects(runPrimedTransaction(ref, () => { throw original; }), error => error === original);
  assert.equal(completed, true);
  assert.equal(removed, true);
});
