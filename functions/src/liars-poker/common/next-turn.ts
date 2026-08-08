/* eslint-disable valid-jsdoc */

import {PublicGamePlayer} from "./types.js";

/**
 * @param players 공개 플레이어 맵
 * @param currentUid 현재 플레이어 UID
 * @return seatIndex 기준 다음 생존 플레이어 UID
 */
export function findNextAlivePlayer(
  players: Record<string, PublicGamePlayer>,
  currentUid: string,
): string {
  // seatIndex 순으로 정렬
  const orderedPlayers = Object.values(players).sort(
    (a, b) => a.seatIndex - b.seatIndex,
  );

  // 현재 플레이어 위치
  const currentIndex = orderedPlayers.findIndex(
    (player) => player.uid === currentUid,
  );

  if (currentIndex === -1) {
    throw new Error("현재 플레이어를 찾을 수 없습니다.");
  }

  // 다음 플레이어 탐색 (마지막이면 처음으로)
  let nextIndex = (currentIndex + 1) % orderedPlayers.length;

  while (nextIndex !== currentIndex) {
    if (orderedPlayers[nextIndex].status === "alive") {
      return orderedPlayers[nextIndex].uid;
    }

    nextIndex = (nextIndex + 1) % orderedPlayers.length;
  }

  // 자기 자신만 살아있는 경우
  return orderedPlayers[currentIndex].uid;
}
