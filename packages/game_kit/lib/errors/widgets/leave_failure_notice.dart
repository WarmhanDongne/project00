// [leave_failure_notice.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [ErrorWidget] : 방 퇴장 실패를 사용자에게 안내함
//
// 즉, 각 게임이 같은 화면 전환 규칙과 예외 처리를 공유하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

/// 게임 중 퇴장 실패 안내를 표시합니다.
///
/// 퇴장 요청이 아직 진행 중이면(중복 탭이나 재접속 화면 같은 다른 경로가 이미
/// 나가는 중) 실패가 아니라 삼켜진 중복 요청입니다. 예전에는 이 구분이 없어,
/// 첫 퇴장이 성공하는 중에 두 번째 호출의 false가 실패 안내를 띄웠습니다.
/// [provider]가 null이면 퇴장 진행 여부를 알 수 없으므로 실패로 봅니다.
/// 안내를 빼먹는 것보다 한 번 더 보여주는 편이 안전합니다.
void showLeaveFailureNotice(BuildContext context, GameRoomContext? provider) {
  if (provider != null && provider.isLeaving) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
}
