/** 게임이 끝난 뒤 끊긴 참가자를 방에서 지우기까지의 유예입니다.
 *
 * 게임 중단의 재접속 유예(60초, `GAME_INTERRUPTION_VOTE_MS`)보다 충분히 길어야
 * 합니다. 짧게 잡으면 재접속 유예 중인 정상 참가자를 지웁니다.
 */
export const GHOST_PLAYER_GRACE_MS = 5 * 60 * 1000;

type GhostPlayer = {
  isConnected?: unknown;
  lastSeen?: unknown;
  role?: unknown;
  status?: unknown;
};

type GhostCleanupState = {
  roomStatus: unknown;
  gameStatus?: unknown;
  players: Record<string, GhostPlayer>;
  now: number;
  graceMs?: number;
};

/**
 * 방에서 지워야 할 유령 참가자 UID를 고릅니다.
 *
 * **왜 필요한가.** 이탈 참가자 제거가 화면 타이머의 `onExpired` 호출에만
 * 의존합니다. 화면 dispose·앱 백그라운드·네트워크 재단절·전원 종료 어느
 * 것이든 그 호출이 사라지면 참가자 노드가 영구히 남습니다. 게임이 끝나
 * 대기실로 돌아왔을 때 나간 사람이 명단에 그대로 보입니다(C-10).
 *
 * **판정 기준 세 가지.**
 * 1. 진행 중(`playing`)에는 아무도 지우지 않습니다. 그 구간의 이탈은 게임
 *    중단(interruption)이 담당하며, 여기서 손대면 중단 상태와 경합합니다.
 * 2. `isConnected !== false`인 참가자는 지우지 않습니다. 값이 없는 옛 노드도
 *    살아 있는 것으로 봅니다(지우는 쪽이 되돌릴 수 없으므로 보수적으로).
 * 3. `lastSeen`이 유예보다 오래된 경우만 지웁니다. `lastSeen`이 아예 없으면
 *    판단 근거가 없으므로 남깁니다.
 *
 * @param {GhostCleanupState} state 현재 방 상태와 참가자입니다.
 * @return {string[]} 지울 참가자 UID입니다. 정렬은 하지 않습니다.
 */
export function findGhostPlayers(state: GhostCleanupState): string[] {
  const roomStatus = state.roomStatus ?? "waiting";
  if (roomStatus === "playing" || state.gameStatus === "playing") return [];

  const graceMs = state.graceMs ?? GHOST_PLAYER_GRACE_MS;
  const ghosts: string[] = [];
  for (const [uid, rawPlayer] of Object.entries(state.players ?? {})) {
    if (!rawPlayer || typeof rawPlayer !== "object") continue;
    const player = rawPlayer as GhostPlayer;
    // 관전자·이미 비활성 처리된 노드는 이 정리의 대상이 아닙니다.
    if ((player.role ?? "player") !== "player") continue;
    if (player.isConnected !== false) continue;
    const lastSeen = player.lastSeen;
    if (typeof lastSeen !== "number" || !Number.isFinite(lastSeen)) continue;
    if (state.now - lastSeen <= graceMs) continue;
    ghosts.push(uid);
  }
  return ghosts;
}
