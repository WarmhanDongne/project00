import assert from "node:assert/strict";
import test from "node:test";
import {createRequire} from "node:module";
import {CleanupDatabase} from "./fake-cleanup-database.mjs";
import {closeAccountHostedRoom} from "../lib/auth/account-room-cleanup.js";

import {deleteAccountResources} from "../lib/auth/delete-account.js";

/**
 * 호출 순서를 기록하는 대역을 만듭니다.
 * @param {object} overrides 실패를 주입할 포트
 * @return {{ports: object, calls: string[]}} 대역과 호출 기록
 */
function stubPorts(overrides = {}) {
  const calls = [];
  const ports = {
    async closeHostedRoom(uid) {
      calls.push(`closeHostedRoom:${uid}`);
      return "ABCDE";
    },
    async deleteUserDocuments(uid) {
      calls.push(`deleteUserDocuments:${uid}`);
    },
    async deleteProfileFiles(uid) {
      calls.push(`deleteProfileFiles:${uid}`);
    },
    async deleteAuthUser(uid) {
      calls.push(`deleteAuthUser:${uid}`);
    },
    ...overrides,
  };
  return {ports, calls};
}

test("회원탈퇴는 데이터를 먼저 지우고 인증 계정을 마지막에 지운다", async () => {
  const {ports, calls} = stubPorts();

  const result = await deleteAccountResources("uid-1", 1000, ports);

  assert.deepEqual(calls, [
    "closeHostedRoom:uid-1",
    "deleteUserDocuments:uid-1",
    "deleteProfileFiles:uid-1",
    "deleteAuthUser:uid-1",
  ]);
  assert.deepEqual(result, {roomCode: "ABCDE", profileFilesDeleted: true});
});

test("프로필 파일 삭제 실패는 탈퇴를 막지 않는다", async () => {
  const {ports, calls} = stubPorts({
    async deleteProfileFiles() {
      throw new Error("storage down");
    },
  });

  const result = await deleteAccountResources("uid-2", 1000, ports);

  assert.equal(result.profileFilesDeleted, false);
  assert.ok(calls.includes("deleteAuthUser:uid-2"));
});

test("문서 삭제가 실패하면 인증 계정은 남긴다", async () => {
  const {ports, calls} = stubPorts({
    async deleteUserDocuments() {
      throw new Error("firestore down");
    },
  });

  await assert.rejects(() => deleteAccountResources("uid-3", 1000, ports));
  assert.ok(!calls.includes("deleteAuthUser:uid-3"));
});

const require = createRequire(import.meta.url);
const adminDatabase = require("firebase-admin/database");
const allocation = {roomInstanceId: "owned-room", allocationGeneration: 1};

function accountRoom(t, mapping = {roomCode: "ABCDE", ...allocation}) {
  const database = new CleanupDatabase();
  t.mock.method(adminDatabase, "getDatabase", () => database);
  database.put("controllerRooms/owner", mapping);
  database.put("rooms/ABCDE", {...allocation, status: "waiting", controllerUid: "owner",
    creationOperationId: "create-operation", controllerConnected: true});
  database.put("roomCreateRequests/owner/create-operation", {...allocation, roomCode: "ABCDE",
    status: "created", controllerSessionId: "private-session"});
  database.put("roomCreateSlots/owner", {...allocation, operationId: "create-operation", status: "created"});
  return database;
}

for (const format of ["object", "legacy string"]) {
  test("account deletion closes the matching owned room with " + format + " mapping", async t => {
    const database = accountRoom(t, format === "object" ? undefined : "ABCDE");
    assert.equal(await closeAccountHostedRoom("owner", 1000), "ABCDE");
    assert.equal(database.value("rooms/ABCDE/status"), "closed");
    assert.equal(database.value("rooms/ABCDE/cleanupAt"), 61_000);
    assert.equal(database.value("controllerRooms/owner"), null);
    assert.equal(database.value("roomCreateSlots/owner/status"), "terminal");
    assert.equal(database.value("roomCreateRequests/owner/create-operation/status"), "terminal");
  });
}

test("account deletion preserves unrelated reserved creation intent and never removes a UID collection", async t => {
  const database = accountRoom(t);
  const pending = {status: "reserved", roomInstanceId: "unresolved-room", allocationGeneration: 3};
  database.put("roomCreateRequests/owner/unknown-operation", pending);
  database.put("roomCreateSlots/owner", {...pending, operationId: "unknown-operation"});
  await closeAccountHostedRoom("owner", 1000);
  assert.deepEqual(database.value("roomCreateRequests/owner/unknown-operation"), pending);
  assert.equal(database.value("roomCreateSlots/owner/status"), "reserved");
  assert.ok(!database.reads.includes("roomCreateRequests/owner"));
});

test("account deletion preserves replacement room when allocation changes after its read", async t => {
  const database = accountRoom(t);
  const replacement = {...allocation, roomInstanceId: "new-room", allocationGeneration: 2,
    controllerUid: "other-owner", status: "waiting"};
  database.beforeTransaction = path => {
    if (path === "rooms/ABCDE") database.put(path, replacement);
  };
  assert.equal(await closeAccountHostedRoom("owner", 1000), null);
  assert.deepEqual(database.value("rooms/ABCDE"), replacement);
  assert.equal(database.value("roomCreateSlots/owner/status"), "created");
});

test("account deletion keeps a replacement mapping and creation slot", async t => {
  const database = accountRoom(t);
  const replacement = {roomCode: "BCDEF", roomInstanceId: "replacement", allocationGeneration: 2};
  database.afterTransaction = path => {
    if (path !== "rooms/ABCDE") return;
    database.afterTransaction = null;
    database.put("controllerRooms/owner", replacement);
    database.put("roomCreateSlots/owner", {...replacement, operationId: "next-operation", status: "created"});
  };
  await closeAccountHostedRoom("owner", 1000);
  assert.deepEqual(database.value("controllerRooms/owner"), replacement);
  assert.equal(database.value("roomCreateSlots/owner/operationId"), "next-operation");
});

test("an already compacted terminal allocation can clear only its matching modern mapping", async t => {
  const database = accountRoom(t);
  database.put("rooms/ABCDE", {...allocation, status: "terminal", cleanupPending: false});
  assert.equal(await closeAccountHostedRoom("owner", 1000), "ABCDE");
  assert.equal(database.value("controllerRooms/owner"), null);
  assert.equal(database.value("rooms/ABCDE/status"), "terminal");
});

for (const state of ["other owner", "other terminal owner", "wrong generation", "missing room", "unidentified legacy room"]) {
  test("account deletion does not guess allocation for " + state, async t => {
    const database = accountRoom(t, state === "unidentified legacy room" ? "ABCDE" : undefined);
    if (state === "other owner") database.put("rooms/ABCDE/controllerUid", "someone-else");
    if (state === "other terminal owner") {
      database.put("rooms/ABCDE/controllerUid", "someone-else");
      database.put("rooms/ABCDE/status", "terminal");
    }
    if (state === "wrong generation") database.put("rooms/ABCDE/allocationGeneration", 2);
    if (state === "missing room") database.put("rooms/ABCDE", null);
    if (state === "unidentified legacy room") database.put("rooms/ABCDE/roomInstanceId", null);
    const before = database.value("rooms/ABCDE");
    assert.equal(await closeAccountHostedRoom("owner", 1000), null);
    assert.deepEqual(database.value("rooms/ABCDE"), before);
    assert.equal(database.value("roomCreateSlots/owner/status"), "created");
  });
}

test("partial account room cleanup is retryable without extending the closure deadline", async t => {
  const database = accountRoom(t);
  database.failures.add("roomCreateSlots/owner");
  await assert.rejects(closeAccountHostedRoom("owner", 1000));
  assert.equal(database.value("rooms/ABCDE/status"), "closed");
  assert.equal(database.value("rooms/ABCDE/cleanupAt"), 61_000);
  assert.equal(await closeAccountHostedRoom("owner", 2000), "ABCDE");
  assert.equal(database.value("rooms/ABCDE/cleanupAt"), 61_000);
  assert.equal(database.value("roomCreateSlots/owner/status"), "terminal");
});
