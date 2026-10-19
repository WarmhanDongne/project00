import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import {assertLocalEnvironment, project} from '../../tool/emulator/local-fixtures.mjs';

const localEnv = {
  GCLOUD_PROJECT: project,
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIREBASE_DATABASE_EMULATOR_HOST: '127.0.0.1:9000',
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
};
test('fixtures reject real projects, absent emulators and remote endpoints before SDK initialization', () => {
  assert.doesNotThrow(() => assertLocalEnvironment(localEnv));
  for (const key of Object.keys(localEnv)) {
    assert.throws(() => assertLocalEnvironment({...localEnv, [key]: undefined}));
    assert.throws(() => assertLocalEnvironment({...localEnv, [key]: 'project0000-ec01e'}));
  }
});
test('local suite includes every app backend on loopback and uses repository rules', () => {
  const config = JSON.parse(readFileSync(new URL('../../firebase.local.json', import.meta.url)));
  for (const name of ['auth', 'database', 'firestore', 'functions', 'storage', 'hub', 'ui']) {
    assert.equal(config.emulators[name].host, '127.0.0.1');
  }
  assert.equal(config.database.rules, 'database.rules.json');
  assert.equal(config.firestore.rules, 'firestore.rules');
  assert.equal(config.storage.rules, 'storage.rules');
  assert.equal(config.functions[0].source, 'build/e13-runtime');
});
