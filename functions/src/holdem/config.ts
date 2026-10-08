/* eslint-disable valid-jsdoc */

export const HOLDEM_MIN_PLAYERS = 2;
export const HOLDEM_MAX_PLAYERS = 8;
export const HOLDEM_STARTING_CHIPS = 1000;
export const HOLDEM_ACTION_MS = 20_000;
export const HOLDEM_HANDS_PER_BLIND_LEVEL = 5;

export const HOLDEM_BLIND_LEVELS = [
  {smallBlind: 10, bigBlind: 20},
  {smallBlind: 20, bigBlind: 40},
  {smallBlind: 40, bigBlind: 80},
  {smallBlind: 80, bigBlind: 160},
  {smallBlind: 160, bigBlind: 320},
] as const;

/** 1부터 시작하는 핸드 번호에 맞는 블라인드를 반환합니다. */
export function holdemBlindsForHand(handNumber: number): {
  smallBlind: number;
  bigBlind: number;
} {
  if (!Number.isInteger(handNumber) || handNumber < 1) {
    throw new Error("핸드 번호는 1 이상의 정수여야 합니다.");
  }
  const requestedLevel = Math.floor(
    (handNumber - 1) / HOLDEM_HANDS_PER_BLIND_LEVEL,
  );
  const level = Math.min(requestedLevel, HOLDEM_BLIND_LEVELS.length - 1);
  return HOLDEM_BLIND_LEVELS[level];
}

/** 제한 시간이 끝났을 때 서버가 적용할 기본 행동입니다. */
export function holdemTimeoutAction(canCheck: boolean): "check" | "fold" {
  return canCheck ? "check" : "fold";
}
