/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {leaveRoomMembership, parseSessionId} from "../room/session-contract.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {RecoveryRoom} from "./recovery-state.js";
import {excludeRecoveryPlayer} from "./game-adapters.js";
import {finalizeGameMutation} from "./game-mutation.js";
import {transactionRandomSeed, withTransactionRandom} from "../common/transaction-random.js";

/** Self leave is scoped to membership, independent of screen or transport readiness. */
export async function leaveSessionRequest(request: CallableRequest<Record<string, unknown>>): Promise<Record<string, unknown>> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const data = request.data;
  const code = typeof data.roomCode === "string" ? data.roomCode.trim().toUpperCase() : "";
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  const roomInstanceId = parseSessionId(data.roomInstanceId, "방 세션");
  const membershipId = parseSessionId(data.membershipId, "참가 세션");
  const operationId = parseSessionId(data.operationId, "작업 ID");
  const seed = transactionRandomSeed();
  const now = Date.now();
  let outcome: Record<string, unknown> = {status: "stale"};
  await runPrimedTransaction(getDatabase().ref(`rooms/${code}`), (raw) => {
    outcome = {status: "stale"};
    if (!raw) return;
    const room = raw as RecoveryRoom;
    if (room.roomInstanceId !== roomInstanceId) {
      outcome = {status: "stale"}; return;
    }
    const before = room.game ? structuredClone(room.game) : undefined;
    outcome = leaveRoomMembership(room, {uid, roomInstanceId, membershipId, operationId, now}, () => {
      if (room.game?.public.status === "playing") withTransactionRandom(seed, () => excludeRecoveryPlayer(room, uid, now));
      if (room.game?.public.recovery) delete room.game.public.recovery.causes?.[`player:${uid}`];
    });
    finalizeGameMutation(room, before, now, before?.public.gameInstanceId ?? "");
    return room;
  });
  return {success: true, ...outcome};
}
