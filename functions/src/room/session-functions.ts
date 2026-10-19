import {traceRoomAction} from "./room-action-timing.js";
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

export function roomSessionContext(room: SessionRoom, uid: string, controllerSessionId?: unknown): Record<string, unknown> {
  // The same account can own the tablet and an independent phone membership.
  // Only a controller credential selects the controller context.
  const controller = controllerSessionId !== undefined && controllerSessionId !== null;
  if (controller) assertControllerSession(room, uid, controllerSessionId);
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
  return roomSessionContext(room, uid, request.data?.controllerSessionId);
});

/** A missing result never cancels an already transmitted request. */
export const game_common_operation_status = onCall({region: "asia-northeast3"}, async (request) => traceRoomAction("game_common_operation_status", async (timing) => {
  const {uid, roomCode} = requestTarget(request.auth?.uid, request.data ?? {});
  const roomInstanceId = parseSessionId(request.data?.roomInstanceId, "방 세션");
  const operationId = parseSessionId(request.data?.operationId, "작업 ID");
  const room = (await timing.measure("room_read", () => getDatabase().ref(`rooms/${roomCode}`).get())).val() as SessionRoom | null;
  if (!room || room.roomInstanceId !== roomInstanceId) return {status: "stale"};
  const saved = roomOperationResult(room, uid, operationId);
  if (saved) return {status: "applied"};
  const player = room.players?.[uid];
  if (request.data?.membershipId && player?.membershipId !== request.data.membershipId) {
    return {status: "stale"};
  }
  return {status: "notApplied", context: roomSessionContext(room, uid, request.data?.controllerSessionId)};
}));

/** Only the server-selected current connection can update presence summaries. */
export const syncRealtimeRoomConnection = onValueWritten({
  ref: "/rooms/{roomCode}/connections/{uid}/{connectionId}/connected", region: "asia-southeast1", retry: true,
}, async (event) => {
  if (event.data.after.val() !== false) return;
  const now = Date.now();
  await runPrimedTransaction(getDatabase().ref(`rooms/${event.params.roomCode}`), (raw) => {
    if (!raw) return;
    const room = raw as SessionRoom;
    if (room.connections?.[event.params.uid]?.[event.params.connectionId]?.connected !== false) return;
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
