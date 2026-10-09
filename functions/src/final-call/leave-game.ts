import {onCall} from "firebase-functions/v2/https";
import {leaveSessionRequest} from "../game-interruption/leave-request.js";

export const game_final_call_leave_game = onCall(
  {region: "asia-northeast3"}, leaveSessionRequest,
);
