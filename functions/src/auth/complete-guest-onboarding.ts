import {randomBytes} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  ONBOARDING_SCHEMA_VERSION,
  isValidNickname,
  parseSignupConsents,
} from "./onboarding-types.js";

/** Prepares an anonymous account without bypassing protected service checks. */
export const completeGuestOnboarding = onCall(
  {region: "asia-northeast3", invoker: "public"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    if (request.auth?.token.firebase?.sign_in_provider !== "anonymous") {
      throw new HttpsError("permission-denied", "게스트 계정만 이용할 수 있습니다.");
    }
    const account = await getAuth().getUser(uid);
    if (account.disabled || account.providerData.length || account.email ||
        account.phoneNumber) {
      throw new HttpsError("permission-denied", "게스트 계정만 이용할 수 있습니다.");
    }

    const consents = parseSignupConsents(request.data?.consents);
    const db = getFirestore();
    const onboardingRef = db.collection("userOnboarding").doc(uid);
    const userRef = db.collection("users").doc(uid);
    const generatedNickname = `게스트${randomBytes(3).toString("hex")}`;
    const result = await db.runTransaction(async (transaction) => {
      const [onboarding, user] = await Promise.all([
        transaction.get(onboardingRef), transaction.get(userRef),
      ]);
      // A retried request must not replace a profile or its original consent.
      if (onboarding.exists || user.exists) {
        if (onboarding.data()?.provider === "anonymous" &&
            onboarding.data()?.status === "complete" &&
            isValidNickname(user.data()?.nickname)) {
          return {
            status: "complete" as const,
            nickname: user.data()?.nickname as string,
          };
        }
        throw new HttpsError("failed-precondition", "계정 상태를 확인해주세요.");
      }
      if (!consents) {
        throw new HttpsError("failed-precondition", "필수 약관에 동의해주세요.");
      }
      const now = FieldValue.serverTimestamp();
      transaction.set(userRef, {
        uid, email: null, nickname: generatedNickname, profileImageUrl: null,
        createdAt: now, updatedAt: now,
        consents: {...consents, agreedAt: now, marketingUpdatedAt: now},
      });
      transaction.set(onboardingRef, {
        uid, provider: "anonymous", status: "complete",
        schemaVersion: ONBOARDING_SCHEMA_VERSION,
        consentVersion: consents.version,
        startedAt: now, updatedAt: now, completedAt: now,
      });
      return {status: "complete" as const, nickname: generatedNickname};
    });
    // Room join defaults and the profile header read Firebase displayName.
    // Repeat this on idempotent retries so a failure after the Firestore commit
    // heals on the next request.
    await getAuth().updateUser(uid, {displayName: result.nickname});
    return {status: result.status};
  },
);
