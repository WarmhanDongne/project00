import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {resolveForcedTimeout} from "./forced-timeout-resolution.js";
import {RealtimeRoom} from "./common/types.js";
import {
  assertController,
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type ForceTimeoutData = {
  roomCode?: unknown;
  controllerSessionId?: unknown;
};

/**
 * 마감이 지난 턴을 태블릿(컨트롤러)이 강제로 해결합니다.
 *
 * 평소 타임아웃은 턴 플레이어 휴대폰의 타이머가 처리하지만, 그 기기가
 * 화면 잠금·백그라운드로 멈추면 아무도 턴을 넘기지 못해 전원이 영구
 * 대기합니다. 이 함수는 그 유일 의존을 없애는 백스톱입니다.
 *
 * 판정과 상태 전이는 [resolveForcedTimeout]이 수행합니다. 이미 다른
 * 명령이 턴을 넘긴 뒤라면 마감이 바뀌어 있으므로 무해하게 ignored로
 * 끝납니다(중복 호출 안전).
 */
export const game_liars_poker_force_timeout = onCall<ForceTimeoutData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid, request.data?.controllerSessionId);
      const game = requireGame(room);

      response = resolveForcedTimeout(game, Date.now());
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "턴 타임아웃을 처리하지 못했습니다.");
    }
    return response;
  },
);
