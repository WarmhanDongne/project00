/**
 * 클라이언트가 보낸 키가 일반 객체의 기본 속성 이름과 겹치지 않는지 봅니다.
 *
 * `__proto__`, `constructor` 같은 이름은 객체에 넣지 않아도 읽히므로
 * 카드 ID나 명령 ID처럼 객체 키로 쓰는 값에서는 받지 않습니다.
 * @param {string} key 클라이언트가 보낸 키
 * @return {boolean} 객체 키로 써도 안전하면 true
 */
export function isSafeRecordKey(key: string): boolean {
  return !(key in Object.prototype);
}

/**
 * 손패처럼 RTDB에서 읽은 객체에서 그 객체가 직접 가진 값만 꺼냅니다.
 *
 * `hand[cardId]`로 바로 읽으면 `__proto__` 같은 키가 손패에 없어도 값을
 * 돌려줘, 실제로 없는 카드를 낸 것처럼 처리될 수 있습니다.
 * @param {Record<string, T>|null|undefined} record 값을 찾을 객체
 * @param {string} key 찾을 키
 * @return {T|undefined} 객체가 직접 가진 값, 없으면 undefined
 */
export function ownEntry<T>(
  record: Record<string, T> | null | undefined,
  key: string,
): T | undefined {
  if (!record || !Object.prototype.hasOwnProperty.call(record, key)) {
    return undefined;
  }
  return record[key];
}
