import assert from "node:assert/strict";
import test from "node:test";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {completeGuestOnboarding} from "../lib/auth/complete-guest-onboarding.js";
import {SIGNUP_TERMS_VERSION} from "../lib/auth/onboarding-types.js";
import {createRealtimeRoom, validateRealtimeRoom, joinRealtimeRoom}
  from "../lib/room/realtime-room-functions.js";

initializeApp({projectId: "demo-guest-onboarding"});
const auth = {uid: "guest-test", token: {firebase: {sign_in_provider: "anonymous"}}};
const consents = {version: SIGNUP_TERMS_VERSION, age14: true, terms: true, privacy: true};
const roomFunctions = [createRealtimeRoom, validateRealtimeRoom, joinRealtimeRoom];

function stub(t, account = {}) {
  const docs = new Map();
  const writes = [];
  t.mock.method(getAuth(), "getUser", async () => ({providerData: [], disabled: false, ...account}));
  t.mock.method(getAuth(), "updateUser", async (uid, data) => {
    writes.push(`auth:${uid}:${data.displayName}`);
  });
  const db = getFirestore();
  const snapshot = (name) => ({exists: docs.has(name), data: () => docs.get(name)});
  t.mock.method(db, "collection", (name) => ({doc: () => ({name, get: async () => snapshot(name)})}));
  t.mock.method(db, "runTransaction", async (fn) => fn({
    get: async (ref) => snapshot(ref.name),
    set: (ref, data) => { writes.push(ref.name); docs.set(ref.name, data); },
  }));
  return {docs, writes};
}

test("anonymous login alone cannot create, validate or join a room; consented guests pass those gates", async (t) => {
  const {docs} = stub(t);
  for (const fn of roomFunctions) {
    await assert.rejects(fn.run({auth, data: {presenceProtocol: 2}}), (e) => e.code === "failed-precondition");
  }
  assert.deepEqual(await completeGuestOnboarding.run({auth, data: {consents}}), {status: "complete"});
  assert.equal(docs.get("userOnboarding").provider, "anonymous");
  assert.equal(docs.get("userOnboarding").status, "complete");
  assert.match(docs.get("users").nickname, /^게스트[0-9a-f]{6}$/);
  assert.equal(docs.get("users").email, null);
  assert.equal(docs.get("users").ownedGames, undefined);
  assert.equal(docs.get("users").consents.marketing, undefined);
  for (const fn of roomFunctions) {
    // Reaches payload validation after the real shared authorization guard.
    // B1 capability must pass before create can reach that guard.
    // Invalid input deliberately avoids any production RTDB access.
    await assert.rejects(fn.run({auth, data: {presenceProtocol: 2}}), (e) => e.code === "invalid-argument");
  }
});

test("guest preparation requires current mandatory consent without granting access on failure", async (t) => {
  const {writes} = stub(t);
  for (const invalid of [undefined, {...consents, terms: false}, {...consents, version: "old"}]) {
    await assert.rejects(completeGuestOnboarding.run({auth, data: {consents: invalid}}),
      (e) => e.code === "failed-precondition");
  }
  assert.equal(writes.length, 0);
});

test("a retry preserves guest nickname, purchases and original consent", async (t) => {
  const {docs, writes} = stub(t);
  await completeGuestOnboarding.run({auth, data: {consents}});
  const original = docs.get("users");
  original.nickname = "변경한이름";
  original.ownedGames = ["game-test"];
  assert.deepEqual(await completeGuestOnboarding.run({auth, data: {}}), {status: "complete"});
  assert.equal(writes.length, 4);
  assert.equal(docs.get("users"), original);
  assert.equal(writes.at(-1), "auth:guest-test:변경한이름");
});

test("a regular or upgraded account cannot use guest preparation to skip signup", async (t) => {
  const {writes} = stub(t, {providerData: [{providerId: "password"}]});
  await assert.rejects(completeGuestOnboarding.run({auth, data: {consents}}),
    (e) => e.code === "permission-denied");
  assert.equal(writes.length, 0);
});

test("guest setup rejects missing or non-anonymous tokens and disabled accounts", async (t) => {
  const {writes} = stub(t, {disabled: true});
  for (const [identity, code] of [[undefined, "unauthenticated"],
    [{uid: "test", token: {firebase: {sign_in_provider: "password"}}}, "permission-denied"],
    [auth, "permission-denied"]]) {
    await assert.rejects(completeGuestOnboarding.run({auth: identity, data: {consents}}),
      (e) => e.code === code);
  }
  assert.equal(writes.length, 0);
});

test("guest setup never overwrites incompatible existing account records", async (t) => {
  const {docs, writes} = stub(t);
  docs.set("userOnboarding", {provider: "legacyPassword", status: "settingProfile"});
  await assert.rejects(completeGuestOnboarding.run({auth, data: {consents}}),
    (e) => e.code === "failed-precondition");
  assert.equal(writes.length, 0);
});
