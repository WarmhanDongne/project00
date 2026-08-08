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
  saveRealtimePlayerSeatIndexes,
} from "./room/realtime-room-functions.js";

export {
  checkEmailDuplicate,
} from "./auth/check-email.js";

export {
  registerProfile,
} from "./auth/register-profile.js";

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
