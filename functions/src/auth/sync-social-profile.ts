import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

import {
  INCOMPLETE_ACCOUNT_TTL_MS,
  ONBOARDING_SCHEMA_VERSION,
  OnboardingProvider,
  OnboardingStatus,
  isValidNickname,
  parseOnboardingStatus,
  resolveSocialSyncStatus,
} from "./onboarding-types.js";

export type SocialProfileData = {
  nickname?: unknown;
  profileImageUrl?: unknown;
};

/**
 * ID 토큰에서 읽는 프로필 필드입니다.
 */
export type SocialProfileToken = {
  name?: unknown;
  picture?: unknown;
  email?: unknown;
};

export type SocialProfileResult = {
  status: OnboardingStatus;
  nickname: string | null;
  profileImageUrl: string | null;
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
 * 소셜 프로필에 사용하는 HTTP(S) 이미지만 허용합니다.
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
 * 소셜 로그인 사용자의 닉네임과 프로필 사진을 Firestore에 병합합니다.
 *
 * 기존 사용자의 다른 필드는 유지하고, 최초 저장일은 새 문서에만 기록합니다.
 * 값이 비어 있으면 필드를 건드리지 않습니다. Apple은 이름을 최초 승인 때만
 * 주기 때문에, 두 번째 로그인부터 넘어오는 빈 이름이 저장된 닉네임을 지우면
 * 안 됩니다.
 * @param {{uid: string, provider: OnboardingProvider,
 * token: SocialProfileToken, data: (SocialProfileData|undefined)}} input
 * 호출자 정보와 클라이언트가 보낸 프로필 값
 * @return {Promise<SocialProfileResult>} 저장된 온보딩 상태와 프로필
 */
export async function syncSocialProfile(input: {
  uid: string;
  provider: OnboardingProvider;
  token: SocialProfileToken;
  data?: SocialProfileData;
}): Promise<SocialProfileResult> {
  const {uid, provider, token, data} = input;
  // 프로필 수정 화면의 새 값을 토큰의 이전 값보다 우선합니다.
  const nickname = optionalText(data?.nickname) ?? optionalText(token.name);
  const profileImageUrl = optionalProfileUrl(data?.profileImageUrl) ??
    optionalProfileUrl(token.picture);
  const email = optionalText(token.email);

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const onboardingRef = db.collection("userOnboarding").doc(uid);
  let status: OnboardingStatus = "settingProfile";

  await db.runTransaction(async (transaction) => {
    const [userSnapshot, onboardingSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(onboardingRef),
    ]);
    const existingStatus = parseOnboardingStatus(
      onboardingSnapshot.data()?.status,
    );
    status = resolveSocialSyncStatus({
      existingStatus,
      hasExistingUser: userSnapshot.exists,
      hasValidExistingNickname: isValidNickname(
        userSnapshot.data()?.nickname,
      ),
    });

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

    const onboardingData: Record<string, unknown> = {
      uid,
      status,
      provider,
      schemaVersion: ONBOARDING_SCHEMA_VERSION,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!onboardingSnapshot.exists) {
      onboardingData.startedAt = FieldValue.serverTimestamp();
    }
    if (status === "complete") {
      onboardingData.expiresAt = FieldValue.delete();
      if (existingStatus !== "complete") {
        onboardingData.completedAt = FieldValue.serverTimestamp();
      }
    } else {
      onboardingData.expiresAt = Timestamp.fromMillis(
        Date.now() + INCOMPLETE_ACCOUNT_TTL_MS,
      );
    }

    transaction.set(userRef, userData, {merge: true});
    transaction.set(onboardingRef, onboardingData, {merge: true});
  });

  return {
    status,
    nickname: nickname ?? null,
    profileImageUrl: profileImageUrl ?? null,
  };
}
