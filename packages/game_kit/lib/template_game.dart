// ============================================================
// import
// ============================================================
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/models/game_room_context.dart';
// ============================================================
// import
// ============================================================

//=====[ 게임 목록 관리 규칙 ]=====
abstract interface class GameCatalog {
  Iterable<TemplateGame> get games;
  TemplateGame? find(String id);
}

//=====[ 비어 있는 기본 카탈로그 ]=====
final class EmptyGameCatalog implements GameCatalog {
  const EmptyGameCatalog();

  @override
  Iterable<TemplateGame> get games => const <TemplateGame>[];

  @override
  TemplateGame? find(String id) => null;
}

//=====[ 서버와 통신할 때 필요한 최소 규칙 ]=====
abstract interface class GameGateway {
  Future<void> startGame(String roomCode, {Map<String, Object?>? options});
  Stream<String?> watchStatus(String roomCode);
}

//=====[ 실제 게임 하나가 구현해야 하는 전체 규칙 ]=====
abstract class TemplateGame implements GameGateway {
  const TemplateGame();

  //[기본 정보] 게임의 식별자와 이름 
  // 서버:id / 사용자 보여주기용:title
  String get id;
  String get title; 

  /// 런타임 다운로드 게임이 요구하는 정확한 에셋 버전입니다. 번들 게임은 0입니다.
  int get requiredAssetVersion => 0;

  //[플레이어 인원] 
  // 고정 인원이면 => (고정숫자)
  // Firestore 있는 최소/최대 인원으로 진행할 경우 NULL
  int? get fixedPlayerCount => null;

  //[함수호출] 플레이어 중도 게임 퇴장
  //
  String get leaveFunctionName;

  //[설정][화면 방향]
  // 가로/세로/둘다  어떤 방향을 지원하는지 정의
  PhoneGameOrientation get phoneOrientation;

  //[에셋][입장테이블]
  // 기본적인 테이블 색상값
  Color get tableColor;

  //[에셋][배경있는 테이블]
  // 배경이미지 입힌 테이블
  ImageProvider? get tableBackgroundImage;

  /// 태블릿의 게임 선택 팝업에 표시할 실제 게임 구성 요소 미리보기입니다.
  Widget buildTabletPreviewArtwork();

  /// 자리 배치 완료 연출에 쓸 위에서 내려다본 테이블 이미지입니다.
  /// null이면 [tableColor]·[tableBackgroundImage]로 그린 원형 테이블을 씁니다.
  ImageProvider? get layoutTableImage => null;

  /// 자리 배치 완료 연출에 쓸 위에서 내려다본 의자 이미지입니다.
  /// 등받이가 위, 앉는 방향이 아래를 향하는 그림이어야 테이블 쪽으로 정확히
  /// 회전합니다. null이면 기본 아이콘 의자를 씁니다.
  ImageProvider? get layoutChairImage => null;

  /// 좌석 배치가 끝난 뒤 실제 게임을 시작합니다.
  ///
  /// [options]는 **게임별 시작 설정**입니다. [buildStartSetupScreen]이 만든
  /// 준비 화면이 고른 값을 그대로 넘겨 줍니다(마피아: `composition` =
  /// `역할 id → 인원수`). 준비 화면이 없는 게임은 null입니다.
  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options});

  /// 자리 배치 **대신** 쓸 게임별 준비 화면입니다. null이면 자리 배치를 씁니다.
  ///
  /// 확정(2026-08): 마피아는 누가 어디 앉는지보다 **이번 판에 어떤 신분이
  /// 들어가는지**가 판을 좌우해서, 이 자리에 역할 배치 화면을 넣습니다.
  ///
  /// 플랫폼 화면이 게임 id로 분기하지 않도록 이 자리를 만들었습니다. 게임을
  /// 추가할 때 플랫폼 코드는 손대지 않습니다.
  ///
  /// [onPrepare]는 자리를 저장하고 [startGame]까지 부릅니다(실패하면 false).
  /// [onComplete]는 게임 화면으로 넘어갑니다. [onCancel]은 게임 선택을 풉니다.
  Widget? buildStartSetupScreen({
    required PlayerLayoutModel layout,
    required Future<bool> Function(
      PlayerLayoutModel layout, {
      Map<String, Object?>? options,
    })
    onPrepare,
    required void Function(PlayerLayoutModel layout) onComplete,
    required Future<bool> Function() onCancel,
  }) => null;

  /// Realtime Database의 게임 status(`waiting`/`playing`/...)를 흘려보냅니다.
  /// `playing`이 되는 시점에 화면을 엽니다.
  @override
  Stream<String?> watchStatus(String roomCode);

  /// 휴대폰 진행 화면을 생성합니다.
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  });

  /// 태블릿 진행 화면을 생성합니다. [playerLayout]을 쓰지 않는 게임은 무시해도 됩니다.
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  });
}
