/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {beginMafiaNight} from "./game.js";
import {MafiaRoom} from "./types.js";
import {
  assertMafiaController,
  assertMafiaPhase,
  MAFIA_REGION,
  mafiaCommandId,
  mafiaRoomCode,
  mafiaUid,
  requireMafiaGame,
} from "./validation.js";

type ConfirmData = {roomCode?: unknown; commandId?: unknown};

/**
 * 내 역할 카드를 확인했다고 알립니다(시안 P1).
 *
 * 누가 확인했는지는 공개해도 신분이 드러나지 않으므로 public에 담습니다.
 * 전원이 확인하면 곧바로 밤으로 넘어갑니다.
 */
export const game_mafia_confirm_role = onCall<ConfirmData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const commandId = mafiaCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      const game = requireMafiaGame(room);
      const previous = mafiaProcessed(game, commandId);
      if (previous) {
        response = previous;
        return room;
      }
      if (!game.public.players[uid]) {
        throw new HttpsError("permission-denied", "이 게임의 참가자가 아닙니다.");
      }
      assertMafiaPhase(game, "roleReveal");

      const now = Date.now();
      // Realtime Database는 빈 배열을 저장하지 않아 읽을 때 undefined가 됩니다.
      const confirmed = new Set(game.public.roleRevealedUids ?? []);
      confirmed.add(uid);
      game.public.roleRevealedUids = [...confirmed];
      game.public.revision += 1;
      game.public.updatedAt = now;

      const total = Object.keys(game.public.players).length;
      // 전원이 확인해도 **곧바로 밤을 시작하지 않습니다.** 태블릿이 10초 여유를
      // 두고 '밤이 됐습니다' 안내를 보여 준 뒤 completeRoleReveal로 넘깁니다.
      // (확정 흐름: 전원 확인 → 10초 → 안내 → 밤)
      response = {
        success: true,
        confirmedCount: confirmed.size,
        totalCount: total,
        phase: game.public.phase,
      };
      recordMafiaCommand(game, commandId, uid, "confirmRole", now, response);
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "역할 확인을 저장하지 못했습니다.");
    }
    return response;
  },
);

type CompleteData = {roomCode?: unknown; controllerSessionId?: unknown};

/**
 * 태블릿의 역할 배분 연출이 끝났음을 알립니다(시안 T1).
 *
 * 아직 확인하지 않은 사람이 있어도 넘어갑니다. 한 명이 카드를 누르지 않아
 * 게임이 멈추는 것을 막기 위한 길입니다.
 */
export const game_mafia_complete_role_reveal = onCall<CompleteData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      assertMafiaController(room, uid, request.data?.controllerSessionId);
      const game = requireMafiaGame(room);
      // 이미 지나간 단계면 그대로 성공으로 답합니다(재시도 안전).
      if (game.public.phase !== "roleReveal") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      beginMafiaNight(game, Date.now());
      response = {success: true, phase: game.public.phase};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "역할 배분을 마치지 못했습니다.");
    }
    return response;
  },
);
