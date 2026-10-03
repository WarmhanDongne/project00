// [game_session_state.dart] 는 여러 게임이 함께 사용하는 게임 상태의 공통 계약을 정의하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryModel] : 공용 세션 컨트롤러가 복구에 사용하는 최소 계약을 정의함
//
// 즉, 게임마다 다른 상태 모양을 공용 컨트롤러가 안전하게 다루기 위해 필요한 파일이다.

//=======================공용 컨트롤러가 요구하는 최소 계약==============================
/// [GameSessionController] 가 게임 상태를 건드릴 때 쓰는 **최소한의** 창구입니다.
///
/// 게임마다 상태 필드가 완전히 다르기 때문에(마피아 40개 · 파이널콜 26개),
/// 공용 컨트롤러가 `copyWith` 를 직접 부를 수는 없습니다. 대신 공용 컨트롤러가
/// 실제로 바꿔야 하는 **네 가지 순간**만 메서드로 노출합니다.
///
/// 각 게임은 자기 `copyWith` 로 이 네 개를 구현합니다. 그래서 어떤 필드를
/// 어떻게 정리할지는 **여전히 게임이 결정합니다.** 공용 코드가 남의 게임
/// 필드를 모르는 채 건드리는 일이 없습니다.
///
/// `T` 는 자기 자신입니다. 각 게임은
/// `class MafiaGameState implements GameSessionState<MafiaGameState>` 처럼
/// 자기 타입을 넣습니다.
abstract interface class GameSessionState<T extends GameSessionState<T>> {
  /// 서버 명령이 진행 중인지입니다. 중복 전송을 막는 데 씁니다.
  bool get commandInFlight;

  /// 화면에 보여 줄 오류 문구입니다. null이면 오류가 없습니다.
  String? get errorMessage;

  /// 명령을 보내기 직전입니다. 진행 표시를 켜고 이전 오류를 지웁니다.
  T markCommandStarted();

  /// 명령이 끝났습니다(성공·실패 무관). 진행 표시를 끕니다.
  T markCommandFinished();

  /// 오류 문구를 바꿉니다. null을 주면 지웁니다.
  T withError(String? message);

  /// 방·게임이 서버에서 사라졌을 때의 종료 상태입니다.
  ///
  /// 정리할 필드가 게임마다 다릅니다(파이널콜은 진행 중인 뽑기까지 비웁니다).
  /// 그래서 공용 코드가 아니라 **각 게임이** 구현합니다.
  T asRemovedGame();
}
