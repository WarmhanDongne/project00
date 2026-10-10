/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {applyRoomPresence, parseSessionId, roomOperationResult, SessionRoom} from "./session-contract.js";
import {assertControllerSession} from "./controller-session.js";
import {runPrimedTransaction} from "./room-transaction.js";
import {RecoveryRoom, registerRecoveryFailure} from "../game-interruption/recovery-state.js";

function requestTarget(uid: string | undefined, data: Record<string, unknown>): {uid: string; roomCode: string} {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const roomCode = typeof data.roomCode === "string" ? data.roomCode.trim().toUpperCase() : "";
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return {uid, roomCode};
}

export function roomSessionContext(room: SessionRoom, uid: string): Record<string, unknown> {
  const controller = room.controllerUid === uid;
  const player = room.players?.[uid];
  if (!controller && player?.status !== "active") {
    throw new HttpsError("permission-denied", "현재 방 참가 자격이 없습니다.");
  }
  return {
    roomInstanceId: room.roomInstanceId, roomStatus: room.status,
    connectionId: controller ? room.controllerCurrentConnectionId : player?.currentConnectionId,
    connectionSeq: (controller ? room.controllerConnectionSeq : player?.connectionSeq) ?? 0,
    ...(controller ? {} : {membershipId: player?.membershipId}),
  };
}

/** Authenticated current membership lookup, including startup CAS recovery. */
export const fetchRealtimeRoomSession = onCall({region: "asia-northeast3"}, async (request) => {
  const {uid, roomCode} = requestTarget(request.auth?.uid, request.data ?? {});
  const room = (await getDatabase().ref(`rooms/${roomCode}`).get()).val() as SessionRoom | null;
  if (!room) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
  if (room.controllerUid === uid) assertControllerSession(room, uid, request.data?.controllerSessionId);
  return roomSessionContext(room, uid);
});

/** A missing result never cancels an already transmitted request. */
export const game_common_operation_status = onCall({region: "asia-northeast3"}, async (request) => {
  const {uid, roomCode} = requestTarget(request.auth?.uid, request.data ?? {});
  const roomInstanceId = parseSessionId(request.data?.roomInstanceId, "방 세션");
  const operationId = parseSessionId(request.data?.operationId, "작업 ID");
  const room = (await getDatabase().ref(`rooms/${roomCode}`).get()).val() as SessionRoom | null;
  if (!room || room.roomInstanceId !== roomInstanceId) return {status: "stale"};
  const saved = roomOperationResult(room, uid, operationId);
  if (saved) return {status: "applied"};
  const player = room.players?.[uid];
  if (request.data?.membershipId && player?.membershipId !== request.data.membershipId) {
    return {status: "stale"};
  }
  if (room.controllerUid === uid) assertControllerSession(room, uid, request.data?.controllerSessionId);
  return {status: "notApplied", context: roomSessionContext(room, uid)};
});

/** Only the server-selected current connection can update presence summaries. */
export const syncRealtimeRoomConnection = onValueWritten({
  ref: "/rooms/{roomCode}/connections/{uid}/{connectionId}", region: "asia-southeast1",
}, async (event) => {
  const now = Date.now();
  await runPrimedTransaction(getDatabase().ref(`rooms/${event.params.roomCode}`), (raw) => {
    if (!raw) return;
    const room = raw as SessionRoom;
    if (!applyRoomPresence(room, event.params.uid, event.params.connectionId, (role, observedAt) => {
      registerRecoveryFailure(
        room as unknown as RecoveryRoom,
        event.params.uid,
        role,
        now,
        "disconnected",
        observedAt,
      );
    })) return;
    return room;
  });
});
