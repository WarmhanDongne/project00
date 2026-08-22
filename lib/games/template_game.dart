import 'package:flutter/widgets.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임을 플랫폼(방 생성/대기, 게임 미리보기, 시작·퇴장)에 연결하는 공용 계약입니다.
///
/// [GameRegistry.games]에 인스턴스를 추가하면 플랫폼 쪽 코드(휴대폰 대기 화면,
/// 태블릿 게임 미리보기, 방 나가기)는 별도 수정 없이 이 게임을 인식합니다.
///
/// ## 컨트롤러 상태 설계 기준
///
/// 서버 상태를 미러링하는 Riverpod 컨트롤러는 게임당 하나로 통일하고(phone/tablet
/// 화면이 같은 소스를 구독), 화면 전용 연출·애니메이션 상태는 원칙적으로 위젯
/// 로컬(StatefulWidget)에 둡니다. 이 기본값이 부족해지는 경우는 하나뿐입니다 —
/// 화면(주로 태블릿)이 여러 형제 위젯 파일로 쪼개져 그 연출 상태를 공유해야 할
/// 때뿐이며, 그럴 때만 서버 상태 컨트롤러와는 별도로 얇은 오케스트레이션 Provider를
/// 추가하세요. 서버 데이터와 화면 연출 플래그를 같은 상태 클래스에 섞지 마세요.
abstract class TemplateGame {
  const TemplateGame();

  /// Firestore `games` 컬렉션 문서 id 및 Realtime Database 방 경로에 쓰이는 식별자.
  String get id;

  String get title;

  /// 정확한 참가 인원이 필요한 게임의 고정 인원입니다.
  ///
  /// null이면 플랫폼의 게임 메타데이터에 있는 최소/최대 인원을 사용합니다.
  int? get fixedPlayerCount => null;

  /// 게임 도중 퇴장할 때 [RoomService.leaveGame]이 호출할 Cloud Function 이름입니다.
  String get leaveFunctionName;

  /// 이 게임의 휴대폰 화면 방향 정책입니다.
  ///
  /// 태블릿은 이 값과 무관하게 항상 가로 고정입니다. 새 게임은 휴대폰 화면에서
  /// 실제로 지원하는 방향을 여기 명시하고, 태블릿용 방향 옵션을 추가하지 마세요.
  PhoneGameOrientation get phoneOrientation;

  /// 게임 배경 이미지의 대표 색상입니다. 배경 이미지가 아직 안 그려졌을 때
  /// 테이블·의자의 바탕색으로 씁니다.
  Color get tableColor;

  /// 자리 배치 완료 연출의 테이블에 입힐 게임 배경 이미지입니다. 이 이미지가
  /// 실제 게임 화면의 배경과 같아야 확대했을 때 이질감 없이 이어집니다.
  /// 준비된 이미지가 없는 게임은 null을 반환해 [tableColor]만 씁니다.
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
  Stream<String?> watchStatus(String roomCode);

  /// 휴대폰 진행 화면을 생성합니다.
  Widget buildPhoneScreen({
    required String roomCode,
    required RoomProvider provider,
    required Future<bool> Function() onExitRoom,
  });

  /// 태블릿 진행 화면을 생성합니다. [playerLayout]을 쓰지 않는 게임은 무시해도 됩니다.
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  });
}
