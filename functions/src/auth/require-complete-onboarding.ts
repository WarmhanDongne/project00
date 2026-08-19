import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  ONBOARDING_SCHEMA_VERSION,
  parseOnboardingStatus,
} from "./onboarding-types.js";

/**
 * Prevents incomplete accounts from entering room and game services.
 * @param {string} uid Authenticated account UID.
 * @return {Promise<void>} Resolves when access is allowed.
 */
export async function assertOnboardingComplete(uid: string): Promise<void> {
  const db = getFirestore();
  const onboardingRef = db.collection("userOnboarding").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const [onboarding, user] = await Promise.all([
    onboardingRef.get(),
    userRef.get(),
  ]);
  const status = parseOnboardingStatus(onboarding.data()?.status);
  if (status === "complete") return;
  if (onboarding.exists) {
    throw new HttpsError(
      "failed-precondition",
      "회원가입을 완료한 뒤 이용해주세요.",
    );
  }

  // Old production users did not have userOnboarding documents. Preserve
  // access when their existing public profile is complete and backfill once.
  const nickname = user.data()?.nickname;
  if (typeof nickname === "string" && nickname.trim().length > 0) {
    await onboardingRef.set({
      uid,
      status: "complete",
      provider: "legacyPassword",
      schemaVersion: ONBOARDING_SCHEMA_VERSION,
      startedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      completedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  throw new HttpsError(
    "failed-precondition",
    "회원가입을 완료한 뒤 이용해주세요.",
  );
}
