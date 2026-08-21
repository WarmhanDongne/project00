import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  INCOMPLETE_ACCOUNT_TTL_MS,
  ONBOARDING_SCHEMA_VERSION,
  OnboardingProvider,
  isValidNickname,
  parseOnboardingStatus,
  resolveLegacyStatus,
} from "./onboarding-types.js";

const REGION = "asia-northeast3";

type ProfileData = {
  nickname?: unknown;
  profileImageUrl?: unknown;
};

/**
 * Requires an authenticated callable request.
 * @param {{uid: string}|undefined} auth Callable authentication context.
 * @return {string} Authenticated UID.
 */
function requireUid(auth: {uid: string} | undefined): string {
  if (!auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return auth.uid;
}

/**
 * Parses an optional public HTTP(S) profile image URL.
 * @param {unknown} value Candidate URL.
 * @return {string|null} Normalized URL or null.
 */
function optionalProfileUrl(value: unknown): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "프로필 사진 주소가 올바르지 않습니다.");
  }
  try {
    const url = new URL(value.trim());
    if (url.protocol !== "https:" && url.protocol !== "http:") throw Error();
    return url.toString();
  } catch {
    throw new HttpsError("invalid-argument", "프로필 사진 주소가 올바르지 않습니다.");
  }
}

/**
 * Builds common fields for an incomplete onboarding document.
 * @param {string} uid Account UID.
 * @param {OnboardingProvider} provider Sign-in provider used by the flow.
 * @return {Record<string, unknown>} Common Firestore fields.
 */
function incompleteFields(uid: string, provider: OnboardingProvider) {
  return {
    uid,
    provider,
    schemaVersion: ONBOARDING_SCHEMA_VERSION,
    updatedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + INCOMPLETE_ACCOUNT_TTL_MS),
  };
}

/** Starts or resumes the post-email-link password step. */
export const beginOnboarding = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const uid = requireUid(request.auth);
    const authUser = await getAuth().getUser(uid);
    if (!authUser.emailVerified) {
      throw new HttpsError(
        "failed-precondition",
        "이메일 링크 인증을 먼저 완료해주세요.",
      );
    }

    const ref = getFirestore().collection("userOnboarding").doc(uid);
    const status = await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const existingStatus = parseOnboardingStatus(snapshot.data()?.status);
      if (existingStatus) return existingStatus;

      transaction.set(ref, {
        ...incompleteFields(uid, "emailLink"),
        status: "settingPassword",
        startedAt: FieldValue.serverTimestamp(),
      });
      return "settingPassword";
    });

    return {status};
  },
);

/** Marks password setup complete and opens the profile step. */
export const advanceOnboarding = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const uid = requireUid(request.auth);
    const ref = getFirestore().collection("userOnboarding").doc(uid);
    const status = await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const currentStatus = parseOnboardingStatus(snapshot.data()?.status);
      if (currentStatus === "settingProfile" || currentStatus === "complete") {
        return currentStatus;
      }
      if (currentStatus !== "settingPassword") {
        throw new HttpsError(
          "failed-precondition",
          "진행 중인 비밀번호 설정 단계가 없습니다.",
        );
      }

      transaction.update(ref, {
        status: "settingProfile",
        updatedAt: FieldValue.serverTimestamp(),
        passwordStepCompletedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + INCOMPLETE_ACCOUNT_TTL_MS),
      });
      return "settingProfile";
    });
    return {status};
  },
);

/** Saves the profile and completes onboarding atomically. */
export const completeOnboardingProfile = onCall<ProfileData>(
  {region: REGION, invoker: "public"},
  async (request) => {
    const uid = requireUid(request.auth);
    const rawNickname = request.data?.nickname;
    if (!isValidNickname(rawNickname)) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2자 이상 12자 이하로 입력해주세요.",
      );
    }
    const nickname = rawNickname.trim();
    const profileImageUrl = optionalProfileUrl(request.data?.profileImageUrl);
    const db = getFirestore();
    const onboardingRef = db.collection("userOnboarding").doc(uid);
    const userRef = db.collection("users").doc(uid);
    const authUser = await getAuth().getUser(uid);

    await db.runTransaction(async (transaction) => {
      const [onboarding, userSnapshot] = await Promise.all([
        transaction.get(onboardingRef),
        transaction.get(userRef),
      ]);
      const status = parseOnboardingStatus(onboarding.data()?.status);
      if (status !== "settingProfile" && status !== "complete") {
        throw new HttpsError(
          "failed-precondition",
          "프로필을 설정할 수 있는 단계가 아닙니다.",
        );
      }

      transaction.set(userRef, {
        uid,
        email: authUser.email ?? null,
        nickname,
        profileImageUrl,
        updatedAt: FieldValue.serverTimestamp(),
        ...(!userSnapshot.exists ? {
          createdAt: FieldValue.serverTimestamp(),
        } : {}),
      }, {merge: true});
      transaction.set(onboardingRef, {
        uid,
        status: "complete",
        schemaVersion: ONBOARDING_SCHEMA_VERSION,
        updatedAt: FieldValue.serverTimestamp(),
        completedAt: FieldValue.serverTimestamp(),
        expiresAt: FieldValue.delete(),
      }, {merge: true});
    });

    await getAuth().updateUser(uid, {
      displayName: nickname,
      photoURL: profileImageUrl ?? undefined,
    });
    return {status: "complete"};
  },
);

/** Backfills an onboarding document for accounts created by the old flow. */
export const recoverLegacyOnboarding = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const uid = requireUid(request.auth);
    const db = getFirestore();
    const onboardingRef = db.collection("userOnboarding").doc(uid);
    const existing = await onboardingRef.get();
    const existingStatus = parseOnboardingStatus(existing.data()?.status);
    if (existingStatus) return {status: existingStatus};

    const [authUser, userSnapshot] = await Promise.all([
      getAuth().getUser(uid),
      db.collection("users").doc(uid).get(),
    ]);
    const isGoogle = authUser.providerData.some(
      (item) => item.providerId === "google.com",
    );
    const status = resolveLegacyStatus({
      hasValidNickname: isValidNickname(userSnapshot.data()?.nickname),
      emailVerified: authUser.emailVerified,
      hasPasswordCredential: Boolean(authUser.passwordHash) || isGoogle,
    });
    if (!status) {
      throw new HttpsError(
        "failed-precondition",
        "이메일 링크 인증을 다시 진행해주세요.",
      );
    }

    const provider: OnboardingProvider = isGoogle ?
      "google" : authUser.passwordHash ? "legacyPassword" : "emailLink";
    await onboardingRef.set({
      uid,
      provider,
      schemaVersion: ONBOARDING_SCHEMA_VERSION,
      status,
      startedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(status === "complete" ? {
        completedAt: FieldValue.serverTimestamp(),
      } : {
        expiresAt: Timestamp.fromMillis(
          Date.now() + INCOMPLETE_ACCOUNT_TTL_MS,
        ),
      }),
    });
    return {status};
  },
);
