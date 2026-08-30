/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";

import {InterruptibleGameState} from "./types.js";
import {runPrimedTransaction} from "../room/room-transaction.js";

// Realtime Database 트리거는 데이터베이스 인스턴스가 있는 리전에만 만들 수
// 있습니다. 자세한 배경은 functions.ts 상단 주석을 보세요.
const DATABASE_TRIGGER_REGION = "asia-southeast1";

export type ControllerPauseOutcome = "paused" | "resumed" | "ignored";

/**
 * 태블릿(진행 기기) 단절 동안 서버 턴 마감을 멈추고, 복구되면 되살립니다.
 *
 * **왜 필요한가.** 참가자 단절은 이미 턴 타이머를 멈춥니다
 * (`beginGameInterruption`이 남은 시간을 보관하고 `turnDeadlineAt`을 null로
 * 만듭니다). 그런데 **태블릿 단절에는 서버가 전혀 반응하지 않았습니다.**
 * 태블릿이 죽어 있는 동안에도 마감은 계속 흐르고, 마감이 지난 턴을 해결하는
 * 백스톱(`game_liars_poker_force_timeout` 등)을 부르는 곳도 태블릿뿐이라
 * 아무도 해결하지 않습니다. 돌아와 보면 턴이 이미 한참 지나 있습니다.
 *
 * **왜 별도 슬롯인가.** 참가자 단절과 태블릿 단절은 동시에 일어날 수 있습니다.
 * `game.server.interruption`을 공유하면 나중에 온 쪽이 앞의 남은 시간을 덮어써
 * 복구할 값이 사라집니다. 먼저 복구하는 쪽은 남은 중단에 시간을 넘깁니다.
 *
 * 두 중단이 겹쳤을 때의 동작:
 * - 참가자 중단이 먼저면 `turnDeadlineAt`이 이미 null이라 이 함수는 null을
 *   보관합니다. 진짜 남은 시간은 참가자 중단이 들고 있습니다.
 * - 태블릿 중단이 먼저면 반대로 참가자 중단이 null을 보관합니다.
 * 마지막 중단이 해소될 때만 보존한 시간으로 deadline을 되살립니다.
 *
 * @param game 게임 상태입니다. 트랜잭션 안에서 직접 수정합니다.
 * @param connected 태블릿의 새 접속 상태입니다.
 * @param now 서버 기준 현재 시각입니다.
 */
export function applyControllerPauseToTurnTimer(
  game: InterruptibleGameState | undefined,
  connected: boolean,
  now: number,
): ControllerPauseOutcome {
  if (!game || game.public.status !== "playing") return "ignored";
  const saved = game.server.controllerPause;

  if (!connected) {
    // 이미 멈춰 있으면 다시 보관하지 않습니다. 두 번 보관하면 두 번째가
    // null(이미 멈춘 상태의 마감)로 덮어써 남은 시간이 사라집니다.
    if (saved) return "ignored";
    const deadline = finiteOrNull(game.public.turnDeadlineAt);
    game.server.controllerPause = {
      startedAt: now,
      previousTurnRemainingMs: deadline === null ?
        null :
        Math.max(0, deadline - now),
    };
    game.public.turnDeadlineAt = null;
    game.public.revision += 1;
    game.public.updatedAt = now;
    return "paused";
  }

  if (!saved) return "ignored";
  const remaining = finiteOrNull(saved.previousTurnRemainingMs);
  const interruption = game.server.interruption;
  if (game.public.interruption) {
    if (interruption && remaining !== null) {
      interruption.previousTurnRemainingMs = remaining;
    }
    game.public.turnDeadlineAt = null;
  } else {
    game.public.turnDeadlineAt = remaining === null ? null : now + remaining;
  }
  delete game.server.controllerPause;
  game.public.revision += 1;
  game.public.updatedAt = now;
  return "resumed";
}

/**
 * 숫자로 계산해도 안전한 값만 통과시킵니다.
 *
 * RTDB는 `null`을 저장하지 않고 **키를 지웁니다.** 다시 읽으면 `undefined`가
 * 되는데 그대로 계산에 쓰면 NaN이 되고 RTDB가 쓰기를 거부합니다
 * (`Data returned contains NaN`). state.ts의 같은 방어와 이유가 같습니다.
 */
function finiteOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

interface ControllerPauseRoom {
  game?: InterruptibleGameState;
  controllerPresence?: {connected?: boolean};
}

/** 늦은 접속 이벤트가 현재 단절/복구 상태를 뒤집지 않도록 최신 값을 대조합니다. */
export function reconcileControllerConnection(
  room: ControllerPauseRoom,
  connected: boolean,
  now: number,
): ControllerPauseOutcome {
  if (room.controllerPresence?.connected !== connected) return "ignored";
  return applyControllerPauseToTurnTimer(room.game, connected, now);
}

/** 태블릿 접속 표시 변화를 서버 턴 마감 정지·복원으로 옮깁니다. */
export const game_common_controller_presence_changed = onValueWritten(
  {
    ref: "/rooms/{roomCode}/controllerPresence/connected",
    region: DATABASE_TRIGGER_REGION,
  },
  async (event) => {
    const wasConnected = event.data.before.val() === true;
    const isConnected = event.data.after.val() === true;
    if (wasConnected === isConnected) return;

    const roomCode = event.params.roomCode;
    await runPrimedTransaction(getDatabase().ref(`rooms/${roomCode}`), (raw) => {
      if (raw === null) return;
      const room = raw as ControllerPauseRoom;
      const outcome = reconcileControllerConnection(
        room,
        isConnected,
        Date.now(),
      );
      // 바꾼 것이 없으면 쓰지 않습니다. 불필요한 쓰기는 클라이언트 구독을
      // 깨우고 revision을 흔듭니다.
      if (outcome === "ignored") return;
      return room;
    });
  },
);
