import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {parseOnboardingStatus} from "./onboarding-types.js";

/**
 * Reports expired incomplete accounts. Deletion intentionally remains disabled
 * until production logs and retention policy are reviewed.
 */
export const cleanupIncompleteAccounts = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every day 03:30",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const snapshot = await getFirestore()
      .collection("userOnboarding")
      .where("expiresAt", "<=", new Date())
      .limit(200)
      .get();

    const candidates = snapshot.docs.filter((document) => {
      return parseOnboardingStatus(document.data().status) !== "complete";
    });
    logger.info("Incomplete account cleanup dry run", {
      dryRun: true,
      candidateCount: candidates.length,
    });
  },
);
