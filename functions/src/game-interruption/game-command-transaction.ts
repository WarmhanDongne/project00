/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {randomUUID} from "node:crypto";
import {Reference} from "firebase-admin/database";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {assertRoomTarget, parseSessionId, recordRoomOperation, roomOperationResult} from "../room/session-contract.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {assertControllerSession} from "../room/controller-session.js";
import {transactionRandomSeed, withTransactionRandom} from "../common/transaction-random.js";
import {assertRecoveryConnection, RecoveryRoom} from "./recovery-state.js";
import {finalizeGameMutation} from "./game-mutation.js";

const TRANSPORT_FIELDS = new Set(["controllerSessionId", "connectionId", "connectionSeq"]);

export async function replayGameCommand(ref: Reference, request: CallableRequest<unknown>, kind: string): Promise<Record<string, unknown> | null> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const data = request.data as Record<string, unknown>;
  const commandId = parseSessionId(data.commandId ?? data.operationId, "명령 ID");
  const room = (await ref.get()).val() as RecoveryRoom | null;
  if (!room) return null;
  assertRoomTarget(room, data.roomInstanceId);
  const payload = Object.fromEntries(Object.entries(data).filter(([key]) => !TRANSPORT_FIELDS.has(key)));
  const saved = roomOperationResult(room, uid, commandId, kind, payload);
  return saved ? saved.response as Record<string, unknown> ?? {success: true} : null;
}

/** Validates and records all game mutations in the same primed room transaction. */
export async function runGameCommandTransaction(
  ref: Reference, request: CallableRequest<unknown>, kind: string,
  update: (raw: unknown, now: number) => unknown,
  response: () => Record<string, unknown> | null = () => ({success: true}),
): Promise<Awaited<ReturnType<Reference["transaction"]>> & {operationResult: Record<string, unknown> | null}> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const data = request.data as Record<string, unknown>;
  const commandId = parseSessionId(data.commandId ?? data.operationId, "명령 ID");
  const newGameId = randomUUID();
  const seed = transactionRandomSeed();
  const now = Date.now();
  const payload = Object.fromEntries(Object.entries(data).filter(([key]) => !TRANSPORT_FIELDS.has(key)));
  let operationResult: Record<string, unknown> | null = null;
  const result = await runPrimedTransaction(ref, (raw) => {
    operationResult = null;
    if (!raw) return;
    const room = raw as RecoveryRoom;
    assertRoomTarget(room, data.roomInstanceId);
    const saved = roomOperationResult(room, uid, commandId, kind, payload);
    if (saved) {
      operationResult = saved.response as Record<string, unknown> ?? {success: true};
      return room;
    }
    if (room.status === "closed" || room.status === "terminal") {
      throw new HttpsError("failed-precondition", "종료된 방입니다.");
    }
    const controller = data.role === "controller";
    if (controller) assertControllerSession(room, uid, data.controllerSessionId);
    assertRecoveryConnection(room, {uid, role: controller ? "controller" : "player",
      membershipId: data.membershipId as string, connectionId: data.connectionId as string,
      connectionSeq: data.connectionSeq as number});
    const isStart = kind.endsWith("_start_game");
    const mayPause = isStart || kind.endsWith("_end_game") || kind.endsWith("_leave_game") || kind.endsWith("_clear_game");
    if (!isStart && room.game) {
      const pub = room.game.public;
      if (data.gameInstanceId !== pub.gameInstanceId || data.phaseSeq !== pub.phaseSeq || data.turnSeq !== pub.turnSeq) {
        throw new HttpsError("failed-precondition", "이전 게임 단계의 요청입니다.", {reason: "staleContext"});
      }
      if (pub.recovery?.paused && !mayPause) {
        throw new HttpsError("failed-precondition", "기기 준비를 기다리고 있습니다.", {reason: "paused"});
      }
    }
    const before = room.game ? structuredClone(room.game) : undefined;
    const next = withTransactionRandom(seed, () => update(raw, now)) as RecoveryRoom | null | undefined;
    if (!next) return next;
    finalizeGameMutation(next, isStart ? undefined : before, now, newGameId);
    operationResult = response();
    if (operationResult && operationResult.success !== false) {
      recordRoomOperation(next, uid, commandId, kind, payload,
        {status: "applied", response: operationResult}, now);
    }
    return next;
  });
  return {...result, operationResult};
}
