/* eslint-disable max-len, valid-jsdoc, require-jsdoc */
import {getDatabase} from "firebase-admin/database";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {findGhostPlayers} from "../room/ghost-player-policy.js";
import {advanceCleanupCursor, cleanupScanPage} from "../room/room-cleanup.js";
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
    const now = Date.now();
    const cursorRef = database.ref("roomCleanupScan/ghostCursor");
    const cursor = (await cursorRef.get()).val() as string | null;
    const query = database.ref("rooms").orderByKey();
    const snapshot = await (cursor ? query.startAt(cursor) : query).limitToFirst(501).get();
    const entries: Array<{code: string; room: GhostRoom}> = [];
    snapshot.forEach((child) => {
      if (child.key) entries.push({code: child.key, room: child.val()});
    });
    const page = cleanupScanPage(entries, cursor, 500);
    let checked = 0; let removed = 0; let failed = 0;
    const candidates = page.page.filter(({room: preview}) =>
      findGhostPlayers({
        roomStatus: preview.status,
        gameStatus: preview.game?.public?.status,
        players: preview.players ?? {},
        room: preview,
        now,
      }).length > 0
    );
    for (let offset = 0; offset < candidates.length; offset += 10) {
      await Promise.all(candidates.slice(offset, offset + 10).map(async ({code}) => {
        try {
          let count = 0;
          const result = await runPrimedTransaction(database.ref(`rooms/${code}`), (raw) => {
            count = 0;
            if (!raw) return;
            const room = raw as GhostRoom;
            const ghosts = findGhostPlayers({
              roomStatus: room.status,
              gameStatus: room.game?.public?.status,
              players: room.players ?? {},
              room,
              now,
            });
            if (ghosts.length === 0) return;
            for (const uid of ghosts) delete room.players?.[uid];
            room.membershipRevision = (room.membershipRevision ?? 0) + 1;
            count = ghosts.length;
            return room;
          });
          checked++;
          if (result.committed) removed += count;
        } catch {
          failed++;
        }
      }));
    }
    // Failed rooms are retried on the next full pass; one failure cannot starve the tail.
    const cursorAdvanced = await advanceCleanupCursor(cursorRef, cursor, page.nextCursor);
    logger.info("Ghost player cleanup", {scanned: page.page.length, checked, removed, failed,
      cursorAdvanced, pageLimitReached: page.page.length === 500, durationMs: Date.now() - now});
  },
);

interface GhostRoom {
  roomInstanceId?: string;
  connections?: import("../room/session-contract.js").SessionRoom["connections"];
  membershipRevision?: number;
  status?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: {public?: {status?: string}};
}
