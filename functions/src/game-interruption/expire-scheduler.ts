/* eslint-disable max-len, valid-jsdoc, require-jsdoc */
import {getDatabase} from "firebase-admin/database";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {findGhostPlayers} from "../room/ghost-player-policy.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {expireRecoveryCauses, RecoveryRoom} from "./recovery-state.js";
const REGION = "asia-northeast3";

/** Deadlines only expose controller decisions; they never exclude or end a game. */
export const cleanupExpiredGameInterruptions = onSchedule({region: REGION,
  schedule: "every 1 minutes", timeZone: "Asia/Seoul"}, async () => {
  const database = getDatabase();
  const now = Date.now();
  const snapshot = await database.ref("rooms").orderByChild("status")
    .equalTo("playing").get();
  const jobs: Promise<unknown>[] = [];
  snapshot.forEach((child) => {
    const preview = child.val() as RecoveryRoom;
    if (!Object.values(preview.game?.public.recovery?.causes ?? {}).some((c) =>
      c.deadlineAt !== undefined && c.deadlineAt <= now && !c.awaitingDecision)) return;
    jobs.push(runPrimedTransaction(child.ref, (raw) => {
      if (!raw) return;
      const room = raw as RecoveryRoom;
      return expireRecoveryCauses(room, now) ? room : undefined;
    }));
  });
  await Promise.all(jobs);
});
export const cleanupGhostRoomPlayers = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const database = getDatabase();
    const snapshot = await database.ref("rooms").limitToFirst(500).get();
    if (!snapshot.exists()) return;

    const jobs: Promise<unknown>[] = [];
    snapshot.forEach((child) => {
      const roomCode = child.key;
      if (!roomCode) return;
      const preview = child.val() as GhostRoom;
      if (findGhostPlayers({
        roomStatus: preview.status,
        gameStatus: preview.game?.public?.status,
        players: preview.players ?? {},
        now: Date.now(),
      }).length === 0) {
        return;
      }

      jobs.push(
        database.ref(`rooms/${roomCode}`).transaction((raw) => {
          if (raw === null) return raw;
          const room = raw as GhostRoom;
          const ghosts = findGhostPlayers({
            roomStatus: room.status,
            gameStatus: room.game?.public?.status,
            players: room.players ?? {},
            now: Date.now(),
          });
          if (ghosts.length === 0) return;
          for (const uid of ghosts) delete room.players?.[uid];
          room.membershipRevision = (room.membershipRevision ?? 0) + 1;
          return room;
        }),
      );
    });
    await Promise.all(jobs);
  },
);

interface GhostRoom {
  membershipRevision?: number;
  status?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: {public?: {status?: string}};
}
