/* eslint-disable require-jsdoc, valid-jsdoc */
import {performance} from "node:perf_hooks";
import {logger} from "firebase-functions";
import {HttpsError} from "firebase-functions/v2/https";

type RoomAction =
  "createRealtimeRoom" | "closeRoom" | "game_common_operation_status";
type Stage =
  "onboarding" | "previous_mapping" | "previous_room" | "creation_slot" |
  "candidate_room" | "reservation" | "allocation" | "reservation_commit" |
  "live_room" | "mapping_read" | "mapping_room" | "mapping_commit" |
  "final_room" | "slot_commit" | "compensation" |
  "room_read" | "close_transaction";

/** Fixed labels and durations only; no identities, payloads or error text. */
export class RoomActionTimer {
  readonly stages: Partial<Record<Stage, {
    count: number; durationMs: number; failures: number;
  }>> = {};
  async measure<T>(stage: Stage, body: () => Promise<T>): Promise<T> {
    const start = performance.now();
    let success = false;
    try {
      const result = await body();
      success = true;
      return result;
    } finally {
      const value = this.stages[stage] ??
        {count: 0, durationMs: 0, failures: 0};
      value.count++;
      value.durationMs += Math.round(performance.now() - start);
      if (!success) value.failures++;
      this.stages[stage] = value;
    }
  }
}

export async function traceRoomAction<T>(
  action: RoomAction, body: (timer: RoomActionTimer) => Promise<T>,
): Promise<T> {
  const start = performance.now();
  const timer = new RoomActionTimer();
  let status = "success";
  let errorCode: string | undefined;
  try {
    return await body(timer);
  } catch (error) {
    status = "failure";
    errorCode = error instanceof HttpsError ? error.code : "internal";
    throw error;
  } finally {
    // Diagnostics must never replace the original result or exception.
    try {
      logger.info("room_action_timing", {action, status,
        durationMs: Math.round(performance.now() - start), stages: timer.stages,
        ...(errorCode ? {errorCode} : {})});
    } catch {
      // Preserve command outcome if the diagnostic sink fails.
    }
  }
}
