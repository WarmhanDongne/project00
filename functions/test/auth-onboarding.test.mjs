import assert from "node:assert/strict";
import test from "node:test";

import {
  canAdvanceToProfile,
  isExpiredIncompleteCandidate,
  isValidNickname,
  parseOnboardingStatus,
  resolveProtectedAccess,
  resolveGoogleSyncStatus,
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

test("Google profile data does not skip a new user's profile step", () => {
  assert.equal(
    resolveGoogleSyncStatus({
      hasExistingUser: false,
      hasValidExistingNickname: false,
    }),
    "settingProfile",
  );
  assert.equal(
    resolveGoogleSyncStatus({
      existingStatus: "settingProfile",
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "settingProfile",
  );
  assert.equal(
    resolveGoogleSyncStatus({
      existingStatus: "complete",
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "complete",
  );
  assert.equal(
    resolveGoogleSyncStatus({
      hasExistingUser: true,
      hasValidExistingNickname: true,
    }),
    "complete",
  );
});
