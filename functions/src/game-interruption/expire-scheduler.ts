/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {excludeFinalCallPlayer} from "../final-call/exclude-player.js";
import {FinalCallGameState} from "../final-call/types.js";
import {excludeLiarsPokerPlayer} from "../liars-poker/exclude-player.js";
import {LiarsPokerGameState} from "../liars-poker/common/types.js";
import {excludeMafiaPlayer} from "../mafia/exclude-player.js";
import {MafiaGameState} from "../mafia/types.js";
import {findGhostPlayers} from "../room/ghost-player-policy.js";
import {resolveExpiredInterruption} from "./expire-resolution.js";
import {FinishNowRoom} from "./finish-now-resolution.js";

const REGION = "asia-northeast3";

/**
 * 마감이 지난 게임 중단과 유령 참가자를 서버가 최종적으로 정리합니다.
 *
 * **왜 필요한가.** 지금까지 중단 만료를 부르는 곳은 휴대폰·태블릿 화면의
 * 카운트다운 타이머뿐이었습니다(`game_interruption_layer.dart`). 서버에는
 * 스케줄도 트리거도 없었습니다. 그래서:
 *
 * - 남은 참가자가 전원 앱을 닫으면 중단이 **영구 잔류**하고 게임이 멈춥니다.
 * - 이탈자의 `players/{uid}` 노드가 **영구 잔류**합니다(C-10).
 * - 방은 `playing`인 채 태블릿 heartbeat 만료로 통째로 삭제됩니다. 그룹이 사라집니다.
 *
 * 이 함수가 그 마지막 책임을 서버로 가져옵니다.
 *
 * ⚠️ **기존 callable을 대체하지 않습니다.** `game_common_interruption_expire`는
 * 화면이 살아 있을 때 즉시 반응하기 위한 경로로 그대로 둡니다. 두 경로가
 * 겹쳐도 `interruptionId` 대조로 먼저 도착한 쪽만 처리합니다. 이름을 바꾸거나
 * 지우면 구버전 앱이 함수를 찾지 못합니다.
 *
 * ⚠️ **1분 주기입니다.** 중단 마감이 60초라 5분 주기로는 최대 5분을 더
 * 기다리게 됩니다. 방 정리(`cleanupStaleRealtimeRooms`, 5분)와 주기가 다른
 * 것은 의도한 것입니다.
 */
export const cleanupExpiredGameInterruptions = onSchedule(
  {
    region: REGION,
    schedule: "every 1 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const database = getDatabase();
    const now = Date.now();
    // status 인덱스는 database.rules.json에 이미 있습니다.
    const snapshot = await database
      .ref("rooms")
      .orderByChild("status")
      .equalTo("playing")
      .limitToFirst(500)
      .get();
    if (!snapshot.exists()) return;

    const jobs: Promise<unknown>[] = [];
    snapshot.forEach((child) => {
      const roomCode = child.key;
      if (!roomCode) return;
      const preview = child.val() as FinishNowRoom;
      const interruption = preview.game?.public.interruption;
      // 트랜잭션은 비쌉니다. 스냅샷으로 후보를 먼저 거릅니다. 트랜잭션 안에서
      // 최신 값을 다시 확인하므로 이 판정이 조금 낡아도 안전합니다.
      if (!interruption || now < interruption.deadlineAt) return;

      jobs.push(
        database.ref(`rooms/${roomCode}`).transaction((raw) => {
          if (raw === null) return raw;
          const room = raw as FinishNowRoom;
          const result = resolveExpiredInterruption(room, Date.now(), excludePlayer);
          // 아무것도 바꾸지 않았으면 쓰지 않습니다. 불필요한 쓰기는 클라이언트
          // 구독을 깨우고 revision을 흔듭니다.
          if (result.outcome === "no-interruption" && !result.interruptionId) {
            return;
          }
          if (result.outcome === "not-expired" ||
              result.outcome === "unsupported-game") {
            return;
          }
          return room;
        }),
      );
    });
    await Promise.all(jobs);
  },
);

/**
 * 게임이 끝났거나 대기실로 돌아온 방에서 오래 끊긴 참가자를 지웁니다.
 *
 * 중단 만료가 지우는 것은 **이탈 당사자 하나**뿐입니다
 * (`finish-now-resolution.ts`, `functions.ts`). 그 전에 이미 끊겨 있던 다른
 * 참가자는 그대로 남아, 게임이 끝나고 대기실로 돌아오면 나간 사람이 명단에
 * 보입니다. 이 함수가 그 잔여물을 정리합니다(C-10).
 *
 * ⚠️ **진행 중(`playing`)인 방은 건드리지 않습니다.** 그 구간의 이탈은 게임
 * 중단이 담당하며, 여기서 손대면 중단 상태와 경합합니다. 판정은
 * `findGhostPlayers`가 소유합니다.
 */
export const cleanupGhostRoomPlayers = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const database = getDatabase();
    const snapshot = await database.ref("rooms").limitToFirst(500).get();
    if (!snapshot.exists()) return;

    const jobs: Promise<unknown>[] = [];
    snapshot.forEach((child) => {
      const roomCode = child.key;
      if (!roomCode) return;
      const preview = child.val() as GhostRoom;
      if (findGhostPlayers({
        roomStatus: preview.status,
        gameStatus: preview.game?.public?.status,
        players: preview.players ?? {},
        now: Date.now(),
      }).length === 0) {
        return;
      }

      jobs.push(
        database.ref(`rooms/${roomCode}`).transaction((raw) => {
          if (raw === null) return raw;
          const room = raw as GhostRoom;
          const ghosts = findGhostPlayers({
            roomStatus: room.status,
            gameStatus: room.game?.public?.status,
            players: room.players ?? {},
            now: Date.now(),
          });
          if (ghosts.length === 0) return;
          for (const uid of ghosts) delete room.players?.[uid];
          return room;
        }),
      );
    });
    await Promise.all(jobs);
  },
);

interface GhostRoom {
  status?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: {public?: {status?: string}};
}

/** 계속 가능한 중단에서 부르는 게임별 제외 처리입니다. */
function excludePlayer(room: FinishNowRoom, uid: string, now: number): void {
  if (room.selectedGame === "final_call") {
    excludeFinalCallPlayer(room.game as unknown as FinalCallGameState, uid, now);
    return;
  }
  if (room.selectedGame === "liars_poker") {
    excludeLiarsPokerPlayer(
      room.game as unknown as LiarsPokerGameState,
      uid,
      now,
    );
    return;
  }
  if (room.selectedGame === "mafia") {
    excludeMafiaPlayer(room.game as unknown as MafiaGameState, uid, now);
  }
}
