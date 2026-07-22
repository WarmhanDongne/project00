import {setGlobalOptions} from "firebase-functions/v2";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// 모든 2세대 함수에 적용되는 기본 실행 옵션입니다.
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});

/** Firebase Functions 연결 상태를 확인하는 기본 HTTP 함수입니다. */
export const healthCheck = onRequest((request, response) => {
  logger.info("healthCheck called", {method: request.method});
  response.status(200).json({ok: true, service: "project00-functions"});
});
