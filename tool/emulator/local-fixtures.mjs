import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {minimalGameCatalog} from '../../functions/scripts/rebuild-game-catalog.mjs';

export const project = 'demo-mosigame-e13';
export const password = 'LocalMosigame123!';
export const accounts = ['tablet', 'phone1', 'phone2', 'phone3', 'phone4'].map(name => ({
  uid: `local-${name}`, email: `${name}@mosigame.test`, displayName: name,
}));

export function assertLocalEnvironment(env = process.env) {
  assert.equal(env.GCLOUD_PROJECT, project, 'Fixture seeding requires the fixed demo project');
  for (const [key, value] of Object.entries({
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
    FIREBASE_DATABASE_EMULATOR_HOST: '127.0.0.1:9000',
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
  })) assert.equal(env[key], value, `Refusing non-local ${key}`);
}

export async function seedLocalFixtures() {
  assertLocalEnvironment();
  const require = createRequire(new URL('../../functions/package.json', import.meta.url));
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const app = initializeApp({projectId: project, credential: {
    getAccessToken: async () => ({access_token: 'owner', expires_in: 3600}),
  }}, 'local-fixtures');
  try {
    for (const user of accounts) {
      try { await getAuth(app).getUser(user.uid); }
      catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
        await getAuth(app).createUser({...user, password, emailVerified: true});
      }
      // Create only: restarting must not overwrite manual profile/catalog edits.
      for (const [path, data] of [
        [`users/${user.uid}`, {nickname: user.displayName, email: user.email, ownedGames: ['mafia']}],
        [`userOnboarding/${user.uid}`, {status: 'complete', provider: 'legacyPassword'}],
      ]) {
        await createDocument(path, data);
      }
    }
    for (const [id, data] of Object.entries(minimalGameCatalog)) {
      await createDocument(`games/${id}`, {...data, enabled: true});
    }
  } finally { await deleteApp(app); }
}

function value(data) {
  if (data === null) return {nullValue: null};
  if (typeof data === 'string') return {stringValue: data};
  if (typeof data === 'boolean') return {booleanValue: data};
  if (typeof data === 'number') return Number.isInteger(data) ? {integerValue: String(data)} : {doubleValue: data};
  if (Array.isArray(data)) return {arrayValue: {values: data.map(value)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]))}};
}

async function createDocument(path, data) {
  const [collection, id] = path.split('/');
  const response = await fetch(`http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents/${collection}?documentId=${id}`, {
    method: 'POST', headers: {Authorization: 'Bearer owner', 'Content-Type': 'application/json'},
    body: JSON.stringify({fields: value(data).mapValue.fields}), signal: AbortSignal.timeout(10000),
  });
  assert.ok(response.ok || response.status === 409, `Local fixture creation failed: HTTP ${response.status}`);
}
