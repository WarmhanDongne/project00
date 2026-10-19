import assert from 'node:assert/strict';
import test from 'node:test';
import {accounts, password, project, seedLocalFixtures} from './local-fixtures.mjs';

const json = async (url, options) => {
  const response = await fetch(url, {...options, signal: AbortSignal.timeout(20000)});
  assert.ok(response.ok, `Local request failed: HTTP ${response.status}`);
  return response.json();
};

test('local fixture login, catalog, callable room, RTDB rules and Storage', {timeout: 120000}, async () => {
  await seedLocalFixtures();
  await seedLocalFixtures(); // A restart must preserve existing accounts/documents.
  const user = accounts[0];
  const login = await json('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-emulator-only', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: user.email, password, returnSecureToken: true}),
  });
  assert.equal(login.localId, user.uid);
  const headers = {Authorization: `Bearer ${login.idToken}`, 'Content-Type': 'application/json'};
  const firestore = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;
  const onboarding = await json(`${firestore}/userOnboarding/${user.uid}`, {headers});
  assert.equal(onboarding.fields.status.stringValue, 'complete');
  assert.equal(onboarding.fields.provider.stringValue, 'legacyPassword');
  const catalog = await json(`${firestore}/games`, {headers});
  assert.equal(catalog.documents.length, 4);
  const callable = async (name, data) => {
    const body = await json(`http://127.0.0.1:5001/${project}/asia-northeast3/${name}`, {
      method: 'POST', headers, body: JSON.stringify({data}),
    });
    assert.ok(!body.error, `${name} failed`);
    return body.result;
  };
  const room = await callable('createRealtimeRoom', {operationId: 'local-smoke-create', presenceProtocol: 2});
  assert.equal(room.success, true);
  const url = `http://127.0.0.1:9000/rooms/${room.roomCode}/roomInstanceId.json?ns=${project}-default-rtdb`;
  assert.equal(await json(`${url}&auth=${login.idToken}`), room.roomInstanceId);
  const denied = await fetch(url, {signal: AbortSignal.timeout(10000)});
  assert.equal(denied.status, 401, 'Unauthenticated room reads must be denied');

  const object = encodeURIComponent(`users/${user.uid}/profile.png`);
  const storage = `http://127.0.0.1:9199/v0/b/${project}.appspot.com/o`;
  const upload = (name) => ({
    method: 'POST',
    headers: {Authorization: `Firebase ${login.idToken}`,
      'X-Goog-Upload-Protocol': 'multipart',
      'Content-Type': 'multipart/related; boundary=local-smoke'},
    body: `--local-smoke\r\nContent-Type: application/json\r\n\r\n${JSON.stringify({name, contentType: 'image/png'})}\r\n` +
      '--local-smoke\r\nContent-Type: image/png\r\n\r\nlocal-test-image\r\n--local-smoke--',
    signal: AbortSignal.timeout(10000),
  });
  await json(`${storage}?uploadType=multipart&name=${object}`, upload(`users/${user.uid}/profile.png`));
  await json(`${storage}/${object}`, {headers});
  const other = 'users/someone-else/profile.png';
  const forbidden = await fetch(`${storage}?uploadType=multipart&name=${encodeURIComponent(other)}`, upload(other));
  assert.ok([401, 403].includes(forbidden.status), 'Storage owner rules must apply');
  await callable('closeRoom', {...room, presenceProtocol: 2, operationId: 'local-smoke-close'});
});
