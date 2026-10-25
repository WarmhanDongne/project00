import {setGlobalOptions} from "firebase-functions/v2";

// =========================================================================
// 모든 함수에 공통으로 적용하는 배포 옵션입니다.
//
// 함수 정의가 만들어질 때 전역 옵션을 읽으므로, index.ts에서 다른 함수
// 모듈보다 먼저 import해야 합니다.
//
// maxInstances: 비정상 호출이나 반복 오류로 인스턴스가 끝없이 늘어나 비용이
// 폭주하지 않도록 함수마다 상한을 둡니다. 2세대 함수는 인스턴스 하나가 동시
// 요청을 여러 개 처리하므로 1차 출시 규모에는 충분합니다. 실제 사용량이
// 늘어 요청이 거절되면 Cloud Functions 로그를 보고 올립니다.
// =========================================================================
export const MAX_INSTANCES_PER_FUNCTION = 20;

setGlobalOptions({maxInstances: MAX_INSTANCES_PER_FUNCTION});
