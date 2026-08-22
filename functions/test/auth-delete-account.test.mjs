import assert from "node:assert/strict";
import test from "node:test";

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
