import {
  DataSnapshot,
  Reference,
} from "firebase-admin/database";

/**
 * Admin RTDB가 서버 값을 로컬 캐시에 받은 뒤에만 트랜잭션을 시작합니다.
 * 초기 캐시가 비어 있을 때 update 함수가 null을 받고 undefined를 반환하면
 * 실제 서버 값을 읽기 전에 committed=false로 끝날 수 있습니다.
 * @param {Reference} ref 트랜잭션을 실행할 RTDB 참조입니다.
 * @param {Function} update 상태 변경 함수입니다.
 * @return {Promise} RTDB 트랜잭션 결과입니다.
 */
export async function runPrimedTransaction(
  ref: Reference,
  update: (currentValue: unknown) => unknown,
): ReturnType<Reference["transaction"]> {
  let valueListener!: (snapshot: DataSnapshot) => void;
  const firstValue = new Promise<DataSnapshot>((resolve, reject) => {
    valueListener = (snapshot) => resolve(snapshot);
    ref.on("value", valueListener, reject);
  });

  try {
    await firstValue;
    return await ref.transaction(update);
  } finally {
    ref.off("value", valueListener);
  }
}
