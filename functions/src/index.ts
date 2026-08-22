import {initializeApp} from "firebase-admin/app";

initializeApp();

// =========================================================================
// 이름 규칙
//   게임 함수      game_<게임 id>_<동작>      예: game_liars_poker_start_game
//   게임 공용 함수  game_common_<영역>_<동작>  예: game_common_interruption_expire
//   방·인증 함수    기존 camelCase 유지
// 배포된 callable 이름을 바꾸면 구버전 앱이 함수를 찾지 못합니다. 이름을 고칠
// 때는 클라이언트 호출부를 같은 커밋에서 함께 고치고 함께 배포하세요.
// =========================================================================

// ---------------------------------------------- 방 (Realtime Database)
export {
  createRealtimeRoom,
  joinRealtimeRoom,
  saveRealtimePlayerSeatIndexes,
  validateRealtimeRoom,
} from "./room/realtime-room-functions.js";

export {
  beginRealtimeRoomSeating,
  cleanupStaleRealtimeRooms,
  closeRoom,
  leaveRealtimeRoom,
  removeRealtimeRoomPlayer,
  resumeRealtimeControllerRoom,
  selectRealtimeRoomGame,
  syncRealtimeRoomGameStatus,
} from "./room/realtime-room-lifecycle.js";

// ---------------------------------------------- 인증
export {checkEmailDuplicate} from "./auth/check-email.js";
export {deleteAccount} from "./auth/delete-account.js";
export {syncGoogleUserProfile} from "./auth/sync-google-profile.js";
export {syncAppleUserProfile} from "./auth/sync-apple-profile.js";

// 클라이언트에서 호출하는 곳이 없는 공개 HTTP 엔드포인트입니다. 회원 정보 저장은
// syncGoogleUserProfile이 담당합니다. 삭제 여부는 따로 결정한 뒤 정리하세요.
export {registerProfile} from "./auth/register-profile.js";

export {
  advanceOnboarding,
  beginOnboarding,
  completeOnboardingProfile,
  recoverLegacyOnboarding,
} from "./auth/onboarding.js";

export {
  cleanupIncompleteAccounts,
} from "./auth/cleanup-incomplete-accounts.js";

// ---------------------------------------------- 게임: Liar's Poker
export {game_liars_poker_start_game} from "./liars-poker/start-game.js";
export {
  game_liars_poker_complete_dealing,
} from "./liars-poker/complete-dealing.js";
export {game_liars_poker_ready_turn} from "./liars-poker/ready-turn.js";
export {game_liars_poker_submit_cards} from "./liars-poker/submit-card.js";
export {game_liars_poker_call_liar} from "./liars-poker/call-liar.js";
export {
  game_liars_poker_pass_challenge,
} from "./liars-poker/pass-challenge.js";
export {
  game_liars_poker_resolve_penalty,
} from "./liars-poker/finish-penalty.js";
export {
  game_liars_poker_force_timeout,
} from "./liars-poker/force-timeout.js";
export {game_liars_poker_end_game} from "./liars-poker/end-game.js";
export {game_liars_poker_leave_game} from "./liars-poker/leave-game.js";

// ---------------------------------------------- 게임: Final Call
export {game_final_call_start_game} from "./final-call/start-game.js";
export {
  game_final_call_complete_dealing,
} from "./final-call/complete-dealing.js";
export {game_final_call_draw_card} from "./final-call/draw-card.js";
export {game_final_call_complete_turn} from "./final-call/complete-turn.js";
export {game_final_call_timeout_turn} from "./final-call/timeout-turn.js";
export {game_final_call_declare} from "./final-call/call.js";
export {game_final_call_submit_hand} from "./final-call/submit-final-hand.js";
export {
  game_final_call_complete_result_reveal,
} from "./final-call/complete-result-reveal.js";
export {game_final_call_start_next_round} from "./final-call/next-round.js";
export {game_final_call_end_game} from "./final-call/end-game.js";
export {game_final_call_clear_game} from "./final-call/clear-game.js";
export {game_final_call_leave_game} from "./final-call/leave-game.js";

// ---------------------------------------------- 게임: 마피아
export {game_mafia_start_game} from "./mafia/start-game.js";
export {
  game_mafia_confirm_role,
  game_mafia_complete_role_reveal,
} from "./mafia/role-reveal.js";
export {
  game_mafia_submit_night_action,
  game_mafia_timeout_night,
} from "./mafia/night.js";
export {game_mafia_complete_morning} from "./mafia/morning.js";
export {
  game_mafia_end_discussion,
  game_mafia_timeout_day,
} from "./mafia/day.js";
export {
  game_mafia_submit_vote,
  game_mafia_timeout_vote,
  game_mafia_complete_vote_result,
} from "./mafia/vote.js";
export {game_mafia_end_game, game_mafia_leave_game} from "./mafia/end-game.js";

// ---------------------------------------------- 게임 공용: 중단·재접속
export {
  game_common_interruption_exclude_player,
  game_common_interruption_expire,
  game_common_interruption_on_connection_changed,
  game_common_interruption_vote_to_continue,
} from "./game-interruption/functions.js";

// 인원 부족이 확정된 중단은 60초 마감을 기다리지 않고 끝낼 수 있습니다(C-11).
// 위 블록과 따로 두는 이유는 export 목록을 함께 고칠 때의 병합 충돌을 줄이기
// 위해서입니다. 구현도 functions.ts와 분리했습니다.
export {
  game_common_interruption_finish_now,
} from "./game-interruption/finish-now.js";

// 화면이 살아 있어야만 중단이 만료되던 구멍을 서버가 막습니다(C-03/C-10).
// 위의 game_common_interruption_expire는 즉시 반응 경로로 **그대로 둡니다.**
export {
  cleanupExpiredGameInterruptions,
  cleanupGhostRoomPlayers,
} from "./game-interruption/expire-scheduler.js";
