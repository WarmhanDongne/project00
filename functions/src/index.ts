import {initializeApp} from "firebase-admin/app";

initializeApp();

// 방 입장 퇴장용
export {
  joinRoom,
  leaveRoom,
  resetRoom,
  selectRoomGame,
} from "./room/room-functions.js";

export {
  createRealtimeRoom,
  joinRealtimeRoom,
  saveRealtimePlayerSeatIndexes,
} from "./room/realtime-room-functions.js";

export {
  checkEmailDuplicate,
} from "./auth/check-email.js";

export {
  registerProfile,
} from "./auth/register-profile.js";

export {
  syncGoogleUserProfile,
} from "./auth/sync-google-profile.js";

export {
  startLiarsPokerGame,
} from "./liars-poker/start-game.js";

export {
  completeLiarsPokerDealing,
} from "./liars-poker/complete-dealing.js";

export {
  endLiarsPokerGame,
} from "./liars-poker/end-game.js";

export {
  leaveLiarsPokerGame,
} from "./liars-poker/leave-game.js";

export {
  submitLiarsPokerCards,
} from "./liars-poker/submit-card.js";

export {
  callLiarsPoker,
} from "./liars-poker/call-liar.js";

export {
  passLiarsPokerChallenge,
} from "./liars-poker/pass-challenge.js";

export {
  resolveLiarsPokerPenalty,
} from "./liars-poker/finish-penalty.js";

export {
  readyLiarsPokerTurn,
} from "./liars-poker/ready-turn.js";

export {startFinalCallGame} from "./final-call/start-game.js";
export {endFinalCallGame} from "./final-call/end-game.js";
export {clearFinalCallGame} from "./final-call/clear-game.js";
export {completeFinalCallDealing} from "./final-call/complete-dealing.js";
export {drawFinalCallCard} from "./final-call/draw-card.js";
export {completeFinalCallTurn} from "./final-call/complete-turn.js";
export {callFinalCall} from "./final-call/call.js";
export {startFinalCallNextRound} from "./final-call/next-round.js";
export {timeoutFinalCallTurn} from "./final-call/timeout-turn.js";
export {leaveFinalCallGame} from "./final-call/leave-game.js";
export {submitFinalCallHand} from "./final-call/submit-final-hand.js";
export {
  completeFinalCallResultReveal,
} from "./final-call/complete-result-reveal.js";

export {
  excludeInterruptedPlayerAndContinue,
  expireInterruptedGame,
  handleGamePlayerConnectionChanged,
  voteToContinueInterruptedGame,
} from "./game-interruption/functions.js";
