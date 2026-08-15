import 'package:flutter/widgets.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 새 게임을 플랫폼(방 생성/대기, 게임 미리보기, 시작·퇴장)에 연결하는 유일한 접점입니다.
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

  /// 게임 도중 퇴장할 때 [RoomService.leaveGame]이 호출할 Cloud Function 이름입니다.
  String get leaveFunctionName;

  /// 좌석 배치가 끝난 뒤 실제 게임을 시작합니다.
  Future<void> startGame(String roomCode);

  /// Realtime Database의 게임 status(`waiting`/`playing`/...)를 흘려보냅니다.
  /// `playing`이 되는 시점에 화면을 엽니다.
  Stream<String?> watchStatus(String roomCode);

  /// 휴대폰 진행 화면을 생성합니다.
  Widget buildPhoneScreen({
    required String roomCode,
    required Future<bool> Function() onExitRoom,
  });

  /// 태블릿 진행 화면을 생성합니다. [playerLayout]을 쓰지 않는 게임은 무시해도 됩니다.
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  });
}
