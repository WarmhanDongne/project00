import 'package:flutter/material.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 중 퇴장 실패 안내를 표시합니다.
///
/// 퇴장 요청이 아직 진행 중이면(중복 탭이나 재접속 화면 같은 다른 경로가 이미
/// 나가는 중) 실패가 아니라 삼켜진 중복 요청입니다. 예전에는 이 구분이 없어,
/// 첫 퇴장이 성공하는 중에 두 번째 호출의 false가 실패 안내를 띄웠습니다.
/// [provider]가 null이면 퇴장 진행 여부를 알 수 없으므로 실패로 봅니다.
/// 안내를 빼먹는 것보다 한 번 더 보여주는 편이 안전합니다.
void showLeaveFailureNotice(BuildContext context, RoomProvider? provider) {
  if (provider != null && provider.isLeaving) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
}
