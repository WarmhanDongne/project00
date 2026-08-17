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

/**
 * 아직 손패가 남아 있는 생존 플레이어 수입니다.
 *
 * FOLD 단계를 열지 판단하는 기준입니다. '살아 있는 인원'이 아니라 '카드를 가진
 * 인원'으로 세야 합니다. 3인 이상이어도 다른 사람들이 이미 손패를 다 냈다면
 * 남은 두 명의 1대1 상황이고, 먼저 손패를 비운 사람들은 벌칙에서 빠집니다.
 *
 * @param players 공개 플레이어 맵
 * @return 손패가 남은 생존 플레이어 수
 */
export function countPlayersWithCards(
  players: Record<string, PublicGamePlayer>,
): number {
  return Object.values(players).filter(
    (player) => player.status === "alive" && player.remainingCardCount > 0,
  ).length;
}

/**
 * 손패가 남아 있는 다음 생존 플레이어를 찾습니다.
 *
 * 라운드 진행 중에는 카드를 모두 낸 플레이어의 턴을 건너뜁니다. 카드가 없으면
 * 제출도 라이어 선언도 할 수 없어 턴이 그 자리에서 멈추기 때문입니다.
 * 3인 이상에서는 남은 플레이어끼리 라운드를 계속 진행합니다.
 *
 * @param players 공개 플레이어 맵
 * @param currentUid 현재 플레이어 UID
 * @return 손패가 남은 다음 생존 플레이어 UID. 아무도 없으면 null
 */
export function findNextPlayerWithCards(
  players: Record<string, PublicGamePlayer>,
  currentUid: string,
): string | null {
  const orderedPlayers = Object.values(players).sort(
    (a, b) => a.seatIndex - b.seatIndex,
  );

  const currentIndex = orderedPlayers.findIndex(
    (player) => player.uid === currentUid,
  );

  if (currentIndex === -1) {
    throw new Error("현재 플레이어를 찾을 수 없습니다.");
  }

  let nextIndex = (currentIndex + 1) % orderedPlayers.length;

  while (nextIndex !== currentIndex) {
    const candidate = orderedPlayers[nextIndex];
    if (candidate.status === "alive" && candidate.remainingCardCount > 0) {
      return candidate.uid;
    }

    nextIndex = (nextIndex + 1) % orderedPlayers.length;
  }

  // 자기 자신을 제외하면 카드를 가진 플레이어가 없습니다. 이 라운드는 더 이상
  // 진행할 수 없으므로 호출한 쪽에서 라운드를 새로 시작해야 합니다.
  return null;
}
