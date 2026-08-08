import {HttpsError, onCall} from "firebase-functions/v2/https";
import {getAuth} from "firebase-admin/auth";

export const checkEmailDuplicate = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const email = request.data?.email;

    if (
      typeof email !== "string" ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "올바른 이메일을 입력해주세요.",
      );
    }

    try {
      await getAuth().getUserByEmail(email.trim().toLowerCase());
      return {isDuplicate: true};
    } catch (error: unknown) {
      if (
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        error.code === "auth/user-not-found"
      ) {
        return {isDuplicate: false};
      }

      console.error(error);
      throw new HttpsError(
        "internal",
        "이메일 확인에 실패했습니다.",
      );
    }
  },
);
