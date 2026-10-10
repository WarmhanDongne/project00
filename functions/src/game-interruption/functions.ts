/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertControllerSession} from "../room/controller-session.js";
import {
  assertRoomTarget,
  parseSessionId,
  recordRoomOperation,
  roomOperationResult,
} from "../room/session-contract.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {
  transactionRandomSeed,
  withTransactionRandom,
} from "../common/transaction-random.js";
import {applyRecoveryReport, assertRecoveryConnection, expireRecoveryCauses, extendRecoveryCause,
  RecoveryReportInput, RecoveryRoom, registerRecoveryFailure, reportStaleController} from "./recovery-state.js";
import {
  decorateRecoveryCauses,
  previewRecoveryExclusion,
  excludeRecoveryPlayer,
} from "./game-adapters.js";
import {finalizeGameMutation} from "./game-mutation.js";

const REGION = "asia-northeast3";
type Data = Record<string, unknown>;
function roomCodeOf(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  return code;
}

async function execute(uid: string | undefined, data: Data, kind: string, controllerOnly: boolean,
  reduce: (room: RecoveryRoom, uid: string, now: number) => Record<string, unknown>): Promise<Record<string, unknown>> {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const code = roomCodeOf(data.roomCode);
  const operationId = parseSessionId(data.commandId ?? data.operationId, "작업 ID");
  const payload = Object.fromEntries(Object.entries(data).filter(([key]) =>
    !["controllerSessionId", "connectionId", "connectionSeq"].includes(key)));
  const seed = transactionRandomSeed();
  const now = Date.now();
  let response: Record<string, unknown> | null = null;
  const result = await runPrimedTransaction(getDatabase().ref(`rooms/${code}`), (raw) => {
    response = null;
    if (!raw) return;
    const room = raw as RecoveryRoom;
    assertRoomTarget(room, data.roomInstanceId);
    const saved = roomOperationResult(room, uid, operationId, kind, payload);
    if (saved) {
      response = saved; return room;
    }
    const role = controllerOnly || data.role === "controller" ? "controller" : "player";
    if (role === "controller") assertControllerSession(room, uid, data.controllerSessionId);
    assertRecoveryConnection(room, {uid, role, membershipId: data.membershipId as string,
      connectionId: data.connectionId as string, connectionSeq: data.connectionSeq as number});
    if (!room.game || data.gameInstanceId !== room.game.public.gameInstanceId) {
      response = {status: "staleContext"};
    } else response = withTransactionRandom(seed, () => reduce(room, uid, now));
    decorateRecoveryCauses(room, now);
    recordRoomOperation(room, uid, operationId, kind, payload, response, now);
    return room;
  });
  if (!result.committed || !response) throw new HttpsError("not-found", "현재 게임을 찾을 수 없습니다.");
  return response;
}

export const game_common_recovery_report = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "report", false, (room, uid, now) => {
    if (request.data.state !== "ready" && request.data.state !== "failed") {
      throw new HttpsError("invalid-argument", "준비 결과가 필요합니다.");
    }
    return applyRecoveryReport(room, {...request.data, uid,
      role: request.data.role === "controller" ? "controller" : "player"} as RecoveryReportInput, now);
  }));

export const game_common_interruption_expire = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "expire", false, (room, _uid, now) => {
    const cause = Object.values(room.game?.public.recovery?.causes ?? {})
      .find((entry) => entry.incidentId === request.data.incidentId);
    if (!cause) return {status: "alreadyResolved"};
    expireRecoveryCauses(room, now);
    return {status: cause.awaitingDecision ? "awaitingDecision" : "notExpired"};
  }));

export const game_common_interruption_wait_more = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "waitMore", true, (room, _uid, now) =>
    extendRecoveryCause(room, request.data.playerUid as string, request.data.incidentId as string, now)));

export const game_common_interruption_exclude_player = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "exclude", true, (room, _uid, now) => {
    const uid = request.data.playerUid as string;
    const cause = room.game?.public.recovery?.causes?.[`player:${uid}`];
    if (!cause || cause.incidentId !== request.data.incidentId ||
        room.game?.public.recovery?.pauseId !== request.data.pauseId) return {status: "alreadyResolved"};
    const preview = previewRecoveryExclusion(room, uid, now);
    if (!preview.canContinue) return {status: "cannotContinue", reason: preview.reason};
    const before = structuredClone(room.game!);
    excludeRecoveryPlayer(room, uid, now);
    delete room.players?.[uid];
    room.membershipRevision = (room.membershipRevision ?? 0) + 1;
    delete room.game?.public.recovery?.causes?.[`player:${uid}`];
    finalizeGameMutation(room, before, now, before.public.gameInstanceId!);
    return {status: "excluded", finished: room.game?.public.status === "finished"};
  }));

export const game_common_interruption_report_stale_player = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "stalePlayer", true, (room, _uid, now) => {
    const uid = request.data.playerUid as string;
    const player = room.players?.[uid];
    const connection = player?.currentConnectionId ? room.connections?.[uid]?.[player.currentConnectionId] : undefined;
    if (!player || !connection || player.currentConnectionId !== request.data.playerConnectionId ||
        player.connectionSeq !== request.data.playerConnectionSeq || connection.lastSeen !== request.data.observedLastSeen) {
      return {status: "staleContext"};
    }
    if (connection.connected !== true) return {status: "alreadyDisconnected"};
    if (now - connection.lastSeen <= 20000) return {status: "notStale"};
    connection.connected = false;
    player.isConnected = false;
    registerRecoveryFailure(room, uid, "player", now, "disconnected", connection.lastSeen);
    return {status: "disconnected"};
  }));

export const game_common_interruption_report_stale_controller = onCall<Data>({region: REGION}, (request) =>
  execute(request.auth?.uid, request.data, "staleController", false, (room, _uid, now) =>
    reportStaleController(room, request.data.observedLastSeen, now)));

/** Presence is a loss signal; connected=true never supplies readiness. */
export const game_common_interruption_on_connection_changed = onValueWritten({
  ref: "/rooms/{roomCode}/players/{uid}/isConnected", region: "asia-southeast1",
}, async (event) => {
  if (event.data.after.val() !== false) return;
  const now = Date.now();
  await runPrimedTransaction(getDatabase().ref(`rooms/${event.params.roomCode}`), (raw) => {
    if (!raw) return;
    const room = raw as RecoveryRoom;
    const player = room.players?.[event.params.uid];
    if (player?.isConnected !== false) return;
    registerRecoveryFailure(
      room, event.params.uid, "player", now, "disconnected",
      typeof player.lastSeen === "number" ? player.lastSeen : now,
    );
    decorateRecoveryCauses(room, now);
    return room;
  });
});
