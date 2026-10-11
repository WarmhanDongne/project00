export const ONBOARDING_STATUSES = [
  "settingPassword",
  "settingProfile",
  "complete",
] as const;

export type OnboardingStatus = typeof ONBOARDING_STATUSES[number];

export const ONBOARDING_PROVIDERS = [
  "emailLink",
  "google",
  "apple",
  "legacyPassword",
] as const;

export type OnboardingProvider = typeof ONBOARDING_PROVIDERS[number];

export const ONBOARDING_SCHEMA_VERSION = 1;
export const INCOMPLETE_ACCOUNT_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * 회원가입 때 보여 주는 약관 묶음(이용약관·개인정보 처리방침)의 버전입니다.
 *
 * 앱 `SignupTermsVersion.current`와 같아야 합니다
 * (`test/auth/onboarding_parity_test.dart`가 대조합니다). 약관을 고치면 두
 * 값을 함께 올립니다.
 */
export const SIGNUP_TERMS_VERSION = "2026-10-12";

/** 회원가입 약관 동의 내용입니다. 필수 세 가지와 선택 마케팅 수신입니다. */
export type SignupConsents = {
  version: string;
  age14: true;
  terms: true;
  privacy: true;
  marketing: boolean;
};

/**
 * 앱이 보낸 약관 동의를 확인합니다. 필수 항목(만 14세 이상·이용약관·개인정보
 * 수집·이용)에 모두 동의했고 지금 약관 버전이면 동의 내용을, 아니면
 * undefined를 돌려줍니다.
 * @param {unknown} value Candidate consents from the client.
 * @return {SignupConsents|undefined} Parsed consents when valid.
 */
export function parseSignupConsents(value: unknown):
  SignupConsents | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const raw = value as Record<string, unknown>;
  if (raw.version !== SIGNUP_TERMS_VERSION) return undefined;
  if (raw.age14 !== true || raw.terms !== true || raw.privacy !== true) {
    return undefined;
  }
  return {
    version: SIGNUP_TERMS_VERSION,
    age14: true,
    terms: true,
    privacy: true,
    marketing: raw.marketing === true,
  };
}

export type OnboardingDocument = {
  uid: string;
  status: OnboardingStatus;
  provider: OnboardingProvider;
  schemaVersion: number;
};

/**
 * Returns a supported onboarding status or undefined.
 * @param {unknown} value Candidate status value.
 * @return {OnboardingStatus|undefined} Parsed status when supported.
 */
export function parseOnboardingStatus(value: unknown):
  OnboardingStatus | undefined {
  return typeof value === "string" &&
    (ONBOARDING_STATUSES as readonly string[]).includes(value) ?
    value as OnboardingStatus : undefined;
}

/**
 * Returns true when a nickname is valid for the public profile.
 * @param {unknown} value Candidate nickname.
 * @return {boolean} Whether the nickname is valid.
 */
export function isValidNickname(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const length = Array.from(value.trim()).length;
  return length >= 2 && length <= 12;
}

/**
 * Resolves old accounts that predate userOnboarding documents.
 * @param {{hasValidNickname: boolean, emailVerified: boolean,
 * hasPasswordCredential: boolean}} input
 * Legacy account facts.
 * @return {OnboardingStatus|undefined} The status to backfill, if safe.
 */
export function resolveLegacyStatus(input: {
  hasValidNickname: boolean;
  emailVerified: boolean;
  hasPasswordCredential: boolean;
}): OnboardingStatus | undefined {
  if (input.hasValidNickname) return "complete";
  if (input.emailVerified) {
    return input.hasPasswordCredential ?
      "settingProfile" : "settingPassword";
  }
  return undefined;
}

/**
 * Resolves the onboarding state after a social sign-in profile sync.
 *
 * A provider display name is useful as a profile-step default, but it is not
 * evidence that this app's profile step was completed. Existing onboarding
 * state is authoritative; only pre-onboarding users with a saved app profile
 * are treated as completed legacy users.
 *
 * Apple sends no name at all after the first authorization, so an empty
 * provider profile must still resolve to settingProfile rather than complete.
 * @param {{existingStatus: (OnboardingStatus|undefined),
 * hasExistingUser: boolean, hasValidExistingNickname: boolean}} input
 * Existing app account facts.
 * @return {OnboardingStatus} The authoritative onboarding state.
 */
export function resolveSocialSyncStatus(input: {
  existingStatus?: OnboardingStatus;
  hasExistingUser: boolean;
  hasValidExistingNickname: boolean;
}): OnboardingStatus {
  if (input.existingStatus) return input.existingStatus;
  return input.hasExistingUser && input.hasValidExistingNickname ?
    "complete" : "settingProfile";
}

/**
 * Checks whether an idempotent password-step advance is allowed.
 * @param {unknown} status Current status.
 * @return {boolean} Whether the request can advance or is already advanced.
 */
export function canAdvanceToProfile(status: unknown): boolean {
  return status === "settingPassword" || status === "settingProfile" ||
    status === "complete";
}

export type ProtectedAccessDecision = "allow" | "backfill" | "deny";

/**
 * Decides whether an account may use room and game services.
 * @param {{status: (OnboardingStatus|undefined),
 * hasOnboardingDocument: boolean, hasValidLegacyNickname: boolean}} input
 * Stored onboarding and legacy profile facts.
 * @return {ProtectedAccessDecision} Access decision for the caller.
 */
export function resolveProtectedAccess(input: {
  status?: OnboardingStatus;
  hasOnboardingDocument: boolean;
  hasValidLegacyNickname: boolean;
}): ProtectedAccessDecision {
  if (input.status === "complete") return "allow";
  if (input.hasOnboardingDocument) return "deny";
  return input.hasValidLegacyNickname ? "backfill" : "deny";
}

/**
 * Returns whether an expired onboarding document is a cleanup candidate.
 * Completed accounts must never be selected, including during dry runs.
 * @param {unknown} status Stored onboarding status.
 * @return {boolean} Whether the expired document is incomplete.
 */
export function isExpiredIncompleteCandidate(status: unknown): boolean {
  return parseOnboardingStatus(status) !== "complete";
}
