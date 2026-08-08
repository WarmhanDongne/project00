import {onRequest} from "firebase-functions/v2/https";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

export const registerProfile = onRequest(
  {
    region: "asia-northeast3",
    cors: true,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({
        result: "fail",
        message: "지원하지 않는 요청 방식입니다.",
      });
      return;
    }

    try {
      // Authorization: Bearer Firebase_ID_TOKEN
      const authorization = request.headers.authorization;

      if (!authorization?.startsWith("Bearer ")) {
        response.status(401).json({
          result: "fail",
          message: "인증 토큰이 필요합니다.",
        });
        return;
      }

      const idToken = authorization.substring(7);

      // Firebase가 발급한 토큰인지 검증
      const decodedToken = await getAuth().verifyIdToken(idToken);

      const uid = decodedToken.uid;
      const email = decodedToken.email;

      if (!email) {
        response.status(400).json({
          result: "fail",
          message: "인증된 이메일을 확인할 수 없습니다.",
        });
        return;
      }

      const {
        nickname,
        phone,
        profileImageUrl,
        marketingAgree,
      } = request.body;

      if (!nickname || !phone) {
        response.status(400).json({
          result: "fail",
          message: "닉네임과 전화번호는 필수입니다.",
        });
        return;
      }

      await getFirestore()
        .collection("users")
        .doc(uid)
        .set({
          uid,
          email,
          nickname,
          phone,
          profileImageUrl: profileImageUrl ?? null,
          marketingAgree: marketingAgree ?? false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

      response.status(201).json({
        result: "success",
        message: "회원가입이 완료되었습니다.",
        data: {
          userId: uid,
          email,
          nickname,
        },
      });
    } catch (error: unknown) {
      console.error("registerProfile error:", error);

      response.status(401).json({
        result: "fail",
        message: "인증에 실패했거나 회원정보 저장에 실패했습니다.",
      });
    }
  },
);
