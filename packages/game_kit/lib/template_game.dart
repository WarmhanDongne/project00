// [template_game.dart] 는 모든 게임이 따라야 하는 공통 규칙을 정의하는 파일이다.
//
// - [GameCatalog] : 등록된 게임 목록 관리
// - [GameGateway] : 게임 시작, 상태 구독 등 서버 통신 규칙
// - [TemplateGame] : 실제 게임들이 공통으로 구현해야 하는 전체 규칙
//
// [MafiaGame], [LiarsPokerGame] 같은 실제 게임은 [TemplateGame]을 상속하며,
// 템플릿에 선언된 필수 함수와 값을 구현해야 한다.
//
// - [abstract] : 직접 생성하지 않고 상속해서 사용
// - [interface] : 구현해야 할 규칙 정의
// - [final] : 다른 클래스가 상속하지 못하게 함
// - [Widget] : Flutter 화면 요소를 반환하는 타입
//
// 즉, 게임마다 구조가 달라지는 것을 막고
// 플랫폼에서 모든 게임을 같은 방식으로 다루기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

//==========[ 게임 목록 관리 규칙 ]==========
abstract interface class GameCatalog {
  //[목록조회] 등록되어 있는 전체 게임
  Iterable<TemplateGame> get games;

  //[게임검색] id로 등록된 게임 찾기
  TemplateGame? find(String id);
}

//==========[ 비어 있는 기본 카탈로그 ]==========
final class EmptyGameCatalog implements GameCatalog {
  const EmptyGameCatalog();

  //[목록조회] 등록된 게임 없음
  @override
  Iterable<TemplateGame> get games => const <TemplateGame>[];

  //[게임검색] 항상 null 반환
  @override
  TemplateGame? find(String id) => null;
}

//==========[ 서버 통신 규칙 ]==========
abstract interface class GameGateway {
  //[시작요청] 서버에 게임 시작 요청
  Future<void> startGame(String roomCode, {Map<String, Object?>? options});

  //[상태구독] 서버의 게임 상태 실시간 감시
  Stream<String?> watchStatus(String roomCode);
}

//==========[ 게임 공통 규칙 ]==========
abstract class TemplateGame implements GameGateway {
  const TemplateGame();

  //==========[ 기본 정보 ]==========

  //[식별정보] 서버에서 사용하는 게임 id
  String get id;

  //[표시정보] 사용자에게 보여주는 게임 이름
  String get title;

  //[에셋버전] 게임 실행에 필요한 에셋 버전
  // 번들 게임이면 0
  // 다운로드 게임이면 해당 게임이 요구하는 버전
  int get requiredAssetVersion => 0;

  //[인원설정] 게임에 필요한 플레이어 인원
  // 고정 인원이면 => 고정 숫자
  // Firestore의 최소/최대 인원을 사용할 경우 => null
  int? get fixedPlayerCount => null;

  //[퇴장처리] 게임 도중 퇴장할 때 사용할 Cloud Function 이름
  String get leaveFunctionName;

  //[화면방향] 휴대폰에서 지원하는 화면 방향
  // 가로 / 세로 / 둘 다
  PhoneGameOrientation get phoneOrientation;

  //==========[ 에셋 ]==========
  //없으면 null => 기본 이미지나 아이콘 사용

  //[테이블색상]
  Color get tableColor;

  //[테이블배경]
  ImageProvider? get tableBackgroundImage;

  //[테이블이미지]
  ImageProvider? get layoutTableImage => null;

  //[의자이미지]
  ImageProvider? get layoutChairImage => null;

  //==========[ 게임 시작 ]==========

  //[게임시작] 좌석 배치 또는 시작 설정 완료 후 서버에 게임 시작 요청
  // roomCode => 시작할 방 코드
  // options => 게임별 추가 시작 설정
  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options});

  //==========[ 게임 상태 ]==========

  //[상태구독]
  //[waiting / starting / playing / result / finished]
  @override
  Stream<String?> watchStatus(String roomCode);

  // ========================[ 게임 화면 ]==========================

  //=============[ 게임 진입 ]=============
  //[     좌석 위치 지정 / 게임 시작 요청     ]
  Widget? buildStartSetupScreen({
    //[Dto] 좌석정보
    required PlayerLayoutModel layout,

    //[요청] 좌석 저장/게임 준비
    required Future<bool> Function(
      PlayerLayoutModel layout, {
      Map<String, Object?>? options,
    })
    onPrepare,
    //[이동] 게임 화면 이동
    required void Function(PlayerLayoutModel layout) onComplete,

    //[요청] 퇴장/종료
    required Future<bool> Function() onCancel,
  }) => null;

  //==========[ UI ]==========

  //[휴대폰]
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  });

  //[태블릿]
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  });
}
