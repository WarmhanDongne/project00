import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 화면이 닫힌 뒤 방을 대기 상태로 되돌립니다.
///
/// **왜 필요한가.** 게임 종료 경로 어디에도 `selectedGame`을 지우는 코드가
/// 없었습니다. 라이어스 포커·파이널 콜·마피아 모두 `endGame()` 뒤에 화면만
/// 닫습니다. 그래서 방이 `status = finished` + `selectedGame` 잔류 상태로
/// 남고:
///
/// - 휴대폰은 룰북과 `곧 시작합니다`에 갇힙니다(`selectedGame`만 보고 그립니다).
/// - `decideRoomJoin`이 `finished`를 `room-finished`로 막아 **신규 참가가
///   불가능**합니다.
/// - `isRestorablePlayerSessionState`가 `finished`에서 false라 앱을 껐다 켠
///   참가자가 **방으로 돌아오지 못합니다.**
///
/// 유일한 탈출구가 "태블릿이 다른 게임을 다시 고르는 것"뿐이었습니다.
///
/// **왜 게임 화면이 닫힌 뒤인가.** 선택 해제는 서버에서 `game` 노드를 통째로
/// 지웁니다(`applyWaitingGameSelection`). 결과 화면이 열려 있는 동안 부르면
/// 휴대폰의 결과가 사라집니다.
///
/// **왜 게임별 화면이 아니라 여기인가.** 세 게임의 종료 경로가 각각 다릅니다
/// (결과 HOME, 설정 종료, 인원 부족 자동 종료). 화면마다 넣으면 새 게임을
/// 추가할 때 빠뜨리고, 경로 하나만 빠져도 증상이 그대로 남습니다. 게임 라우트를
/// **push한 쪽**에서 `whenComplete`로 한 번 거는 편이 빠짐없이 적용됩니다.
Future<void> restoreRoomToWaiting(RoomProvider provider) async {
  // 방을 이미 떠났으면 되돌릴 것이 없습니다.
  if (provider.roomCode == null) return;
  // 아직 진행 중이면 건드리지 않습니다. 게임 화면을 닫았지만 서버는 아직
  // playing인 경우(태블릿만 화면을 벗어난 경우)가 있습니다. 여기서 선택을
  // 해제하면 서버가 거부하고 화면에 불필요한 오류가 뜹니다.
  if (!provider.isRoomFinished) return;
  // 실패해도 조용히 넘깁니다. 사용자는 이미 대기실을 보고 있고, 서버 정리
  // 스케줄과 다음 게임 선택이 같은 일을 다시 합니다.
  await provider.clearSelectedGame();
}

/// 태블릿 앱이 결과 화면 직후 종료됐다가 홈으로 복구된 경우를 정리합니다.
///
/// 일반 게임 경로는 결과 화면이 닫힌 뒤 [restoreRoomToWaiting]을 부릅니다. 하지만
/// 결과 직후 프로세스가 종료되면 `whenComplete`가 실행되지 않습니다. 재실행한
/// 태블릿 홈이 현재 화면이고, 게임과 방 상태가 모두 `finished`로 동기화된 뒤에만
/// 같은 정리를 호출합니다. 결과 화면이 아직 열려 있거나 진행 중인 판은 건드리지
/// 않습니다.
Future<bool> restoreFinishedRoomOnControllerHome({
  required RoomProvider provider,
  required String? gameStatus,
  required bool isControllerHomeCurrent,
  required bool isOpeningGame,
}) async {
  if (!isControllerHomeCurrent || isOpeningGame) return false;
  if (gameStatus != 'finished' || !provider.isRoomFinished) return false;
  await restoreRoomToWaiting(provider);
  return true;
}
