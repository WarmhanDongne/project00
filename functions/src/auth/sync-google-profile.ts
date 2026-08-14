import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-northeast3";

type SyncGoogleProfileData = {
  nickname?: unknown;
  profileImageUrl?: unknown;
};

/**
 * 비어 있지 않은 문자열만 반환합니다.
 * @param {unknown} value 확인할 값
 * @return {string|undefined} 정리된 문자열 또는 undefined
 */
function optionalText(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const text = value.trim();
  return text.length > 0 ? text : undefined;
}

/**
 * Google 프로필에 사용하는 HTTP(S) 이미지만 허용합니다.
 * @param {unknown} value 확인할 프로필 이미지 URL
 * @return {string|undefined} 정리된 HTTP(S) URL 또는 undefined
 */
function optionalProfileUrl(value: unknown): string | undefined {
  const text = optionalText(value);
  if (!text) return undefined;

  try {
    const url = new URL(text);
    return url.protocol === "https:" || url.protocol === "http:" ?
      url.toString() : undefined;
  } catch {
    return undefined;
  }
}

/**
 * 로그인 사용자의 닉네임과 프로필 사진을 Firestore에 병합합니다.
 * 기존 사용자의 다른 필드는 유지하고, 최초 저장일은 새 문서에만 기록합니다.
 */
export const syncGoogleUserProfile = onCall<SyncGoogleProfileData>(
  {region: REGION},
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = auth.uid;
    const token = auth.token;
    // 프로필 수정 화면의 새 값을 토큰의 이전 값보다 우선합니다.
    const nickname = optionalText(request.data?.nickname) ??
      optionalText(token.name);
    const profileImageUrl = optionalProfileUrl(request.data?.profileImageUrl) ??
      optionalProfileUrl(token.picture);
    const email = optionalText(token.email);

    const userRef = getFirestore().collection("users").doc(uid);
    const userSnapshot = await userRef.get();
    const userData: Record<string, unknown> = {
      uid,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (email) userData.email = email;
    if (nickname) userData.nickname = nickname;
    if (profileImageUrl) userData.profileImageUrl = profileImageUrl;
    if (!userSnapshot.exists) {
      userData.createdAt = FieldValue.serverTimestamp();
    }

    await userRef.set(userData, {merge: true});

    return {
      success: true,
      nickname: nickname ?? null,
      profileImageUrl: profileImageUrl ?? null,
    };
  },
);
