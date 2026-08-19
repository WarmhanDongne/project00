export const ONBOARDING_STATUSES = [
  "settingPassword",
  "settingProfile",
  "complete",
] as const;

export type OnboardingStatus = typeof ONBOARDING_STATUSES[number];

export const ONBOARDING_PROVIDERS = [
  "emailLink",
  "google",
  "legacyPassword",
] as const;

export type OnboardingProvider = typeof ONBOARDING_PROVIDERS[number];

export const ONBOARDING_SCHEMA_VERSION = 1;
export const INCOMPLETE_ACCOUNT_TTL_MS = 7 * 24 * 60 * 60 * 1000;

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
 * Resolves the onboarding state after a Google sign-in profile sync.
 *
 * A Google display name is useful as a profile-step default, but it is not
 * evidence that this app's profile step was completed. Existing onboarding
 * state is authoritative; only pre-onboarding users with a saved app profile
 * are treated as completed legacy users.
 * @param {{existingStatus: (OnboardingStatus|undefined),
 * hasExistingUser: boolean, hasValidExistingNickname: boolean}} input
 * Existing app account facts.
 * @return {OnboardingStatus} The authoritative onboarding state.
 */
export function resolveGoogleSyncStatus(input: {
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
