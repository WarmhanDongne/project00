import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  SocialProfileData,
  syncSocialProfile,
} from "./sync-social-profile.js";

const REGION = "asia-northeast3";

/**
 * Apple 로그인 사용자의 닉네임과 프로필 사진을 Firestore에 병합합니다.
 *
 * Apple은 이름을 최초 승인 때 한 번만 내려주고 프로필 사진은 아예 주지
 * 않습니다. 그래서 값이 비어 있는 것이 정상이며, 그 경우 온보딩은
 * settingProfile 단계로 이어져 사용자가 직접 입력합니다.
 */
export const syncAppleUserProfile = onCall<SocialProfileData>(
  {region: REGION},
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const result = await syncSocialProfile({
      uid: auth.uid,
      provider: "apple",
      token: auth.token,
      data: request.data,
    });

    return {success: true, ...result};
  },
);
