import assert from "node:assert/strict";
import test from "node:test";

import {
  ONBOARDING_PROVIDERS,
  canAdvanceToProfile,
  isExpiredIncompleteCandidate,
  isValidNickname,
  parseOnboardingStatus,
  resolveProtectedAccess,
  resolveSocialSyncStatus,
  resolveLegacyStatus,
} from "../lib/auth/onboarding-types.js";

test("onboarding status only accepts known server states", () => {
  assert.equal(parseOnboardingStatus("settingPassword"), "settingPassword");
  assert.equal(parseOnboardingStatus("settingProfile"), "settingProfile");
  assert.equal(parseOnboardingStatus("complete"), "complete");
  assert.equal(parseOnboardingStatus("unknown"), undefined);
});

test("protected services only allow completed or safe legacy accounts", () => {
  assert.equal(
    resolveProtectedAccess({
      status: "complete",
      hasOnboardingDocument: true,
      hasValidLegacyNickname: true,
    }),
    "allow",
  );
  for (const status of ["settingPassword", "settingProfile"]) {
    assert.equal(
      resolveProtectedAccess({
        status,
        hasOnboardingDocument: true,
        hasValidLegacyNickname: true,
      }),
      "deny",
    );
  }
  assert.equal(
    resolveProtectedAccess({
      hasOnboardingDocument: false,
      hasValidLegacyNickname: true,
    }),
    "backfill",
  );
  assert.equal(
    resolveProtectedAccess({
      hasOnboardingDocument: false,
      hasValidLegacyNickname: false,
    }),
    "deny",
  );
});

test("cleanup dry-run candidates never include completed accounts", () => {
  assert.equal(isExpiredIncompleteCandidate("complete"), false);
  assert.equal(isExpiredIncompleteCandidate("settingPassword"), true);
  assert.equal(isExpiredIncompleteCandidate("settingProfile"), true);
  assert.equal(isExpiredIncompleteCandidate("unknown"), true);
});

test("legacy accounts resume without deleting auth users", () => {
  assert.equal(
    resolveLegacyStatus({
      hasValidNickname: true,
      emailVerified: false,
      hasPasswordCredential: false,
    }),
    "complete",
  );
  assert.equal(
    resolveLegacyStatus({
      hasValidNickname: false,
      emailVerified: true,
      hasPasswordCredential: true,
    }),
    "settingProfile",
  );
  assert.equal(
    resolveLegacyStatus({
      hasValidNickname: false,
      emailVerified: false,
      hasPasswordCredential: false,
    }),
    undefined,
  );
  assert.equal(
    resolveLegacyStatus({
      hasValidNickname: false,
      emailVerified: true,
      hasPasswordCredential: false,
    }),
    "settingPassword",
  );
});

test("nickname and password-step transitions are constrained", () => {
  assert.equal(isValidNickname("방장"), true);
  assert.equal(isValidNickname("a"), false);
  assert.equal(isValidNickname("1234567890123"), false);
  assert.equal(canAdvanceToProfile("settingPassword"), true);
  assert.equal(canAdvanceToProfile("settingProfile"), true);
  assert.equal(canAdvanceToProfile("complete"), true);
  assert.equal(canAdvanceToProfile("emailInput"), false);
});

test("social profile data does not skip a new user's profile step", () => {
  assert.equal(
    resolveSocialSyncStatus({
      hasExistingUser: false,
      hasValidExistingNickname: false,
    }),
    "settingProfile",
  );
  assert.equal(
    resolveSocialSyncStatus({
      existingStatus: "settingProfile",
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "settingProfile",
  );
  assert.equal(
    resolveSocialSyncStatus({
      existingStatus: "complete",
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "complete",
  );
  assert.equal(
    resolveSocialSyncStatus({
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "complete",
  );
});

//=======================Apple 소셜 로그인==============================
// Apple은 이름을 최초 승인 때만 주고 사진은 주지 않습니다. 프로필 값이
// 비어 있다고 온보딩을 건너뛰거나, 비밀번호 단계로 되돌리면 안 됩니다.
test("Apple sign-in lands on the profile step, never the password step", () => {
  assert.equal(
    resolveSocialSyncStatus({
      hasExistingUser: false,
      hasValidExistingNickname: false,
    }),
    "settingProfile",
  );
  // 두 번째 로그인. 이름이 안 와도 저장된 닉네임이 있으면 완료 상태입니다.
  assert.equal(
    resolveSocialSyncStatus({
      existingStatus: "complete",
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "complete",
  );
});

test("legacy recovery treats Apple accounts as credentialed", () => {
  // isSocial이 hasPasswordCredential로 들어가는 경로입니다. 이 값이 false면
  // 소셜 사용자가 비밀번호 설정 화면으로 떨어집니다.
  assert.equal(
    resolveLegacyStatus({
      hasValidNickname: false,
      emailVerified: true,
      hasPasswordCredential: true,
    }),
    "settingProfile",
  );
});

test("apple is a stored onboarding provider", () => {
  assert.ok(ONBOARDING_PROVIDERS.includes("apple"));
  assert.ok(ONBOARDING_PROVIDERS.includes("google"));
});
