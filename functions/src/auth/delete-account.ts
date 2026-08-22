import {getAuth} from "firebase-admin/auth";
import {getDatabase} from "firebase-admin/database";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-northeast3";
// realtime-room-lifecycle.ts의 closeRoom과 같은 보존 시간입니다.
const CLOSED_ROOM_RETENTION_MS = 60 * 1000;

export type AccountDeletionResult = {
  /** 함께 닫은 대기방 코드. 진행 중인 방이 없으면 null입니다. */
  roomCode: string | null;
  /** 프로필 사진 삭제까지 마쳤는지 여부입니다. */
  profileFilesDeleted: boolean;
};

/**
 * 회원탈퇴에 필요한 저장소 작업입니다. 테스트에서 대역으로 바꿔 끼웁니다.
 */
export type AccountDeletionPorts = {
  closeHostedRoom(uid: string, now: number): Promise<string | null>;
  deleteUserDocuments(uid: string): Promise<void>;
  deleteProfileFiles(uid: string): Promise<void>;
  deleteAuthUser(uid: string): Promise<void>;
};

/**
 * 탈퇴 순서를 고정합니다.
 *
 * 인증 계정은 항상 마지막에 지웁니다. 앞 단계가 실패하면 계정이 그대로 남아
 * 사용자가 다시 시도할 수 있고, 주인 없는 데이터도 생기지 않습니다.
 * 프로필 파일 삭제만 실패해도 탈퇴는 계속합니다. 남은 이미지는 접근 경로가
 * 없는 고아 파일이라 계정을 살려두는 쪽이 더 나쁩니다.
 * @param {string} uid 탈퇴하는 사용자 uid
 * @param {number} now 방 정리 시각 기준이 되는 현재 시각(ms)
 * @param {AccountDeletionPorts} ports 저장소 작업 모음
 * @return {Promise<AccountDeletionResult>} 닫은 방 코드와 파일 삭제 결과
 */
export async function deleteAccountResources(
  uid: string,
  now: number,
  ports: AccountDeletionPorts,
): Promise<AccountDeletionResult> {
  const roomCode = await ports.closeHostedRoom(uid, now);
  await ports.deleteUserDocuments(uid);

  let profileFilesDeleted = true;
  try {
    await ports.deleteProfileFiles(uid);
  } catch (error) {
    profileFilesDeleted = false;
    logger.warn("Profile file deletion failed during account deletion", {
      uid,
      error,
    });
  }

  await ports.deleteAuthUser(uid);
  return {roomCode, profileFilesDeleted};
}

/**
 * 실제 Firebase 자원을 사용하는 기본 구현입니다.
 * @return {AccountDeletionPorts} admin SDK로 동작하는 저장소 작업 모음
 */
function adminPorts(): AccountDeletionPorts {
  return {
    async closeHostedRoom(uid, now) {
      const database = getDatabase();
      const controllerRoomRef = database.ref(`controllerRooms/${uid}`);
      const mappedRoom = await controllerRoomRef.get();
      const roomCode = mappedRoom.val();

      if (typeof roomCode === "string" && roomCode.length > 0) {
        const roomRef = database.ref(`rooms/${roomCode}`);
        if ((await roomRef.get()).exists()) {
          await roomRef.update({
            status: "closed",
            controllerConnected: false,
            controllerPresence: {connected: false, lastSeen: now},
            cleanupAt: now + CLOSED_ROOM_RETENTION_MS,
          });
        }
        await controllerRoomRef.remove();
      }

      // 방 생성 재시도용 기록도 uid로 묶여 있어 함께 지웁니다.
      await database.ref(`roomCreateRequests/${uid}`).remove();
      return typeof roomCode === "string" ? roomCode : null;
    },

    async deleteUserDocuments(uid) {
      const db = getFirestore();
      const batch = db.batch();
      batch.delete(db.collection("users").doc(uid));
      batch.delete(db.collection("userOnboarding").doc(uid));
      await batch.commit();
    },

    async deleteProfileFiles(uid) {
      await getStorage().bucket().deleteFiles({prefix: `users/${uid}/`});
    },

    async deleteAuthUser(uid) {
      await getAuth().deleteUser(uid);
    },
  };
}

/** 로그인한 사용자가 자신의 계정과 데이터를 지웁니다. */
export const deleteAccount = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  try {
    const result = await deleteAccountResources(uid, Date.now(), adminPorts());
    logger.info("Account deleted", {uid, ...result});
    return {success: true, ...result};
  } catch (error) {
    logger.error("Account deletion failed", {uid, error});
    throw new HttpsError("internal", "회원탈퇴에 실패했습니다.");
  }
});
