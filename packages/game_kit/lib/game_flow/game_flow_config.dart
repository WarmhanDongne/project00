// [game_flow_config.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [FlowConfig] : 게임의 공통 단계·안내·종료 흐름을 정의함
//
// 즉, 각 게임이 같은 화면 전환 규칙과 예외 처리를 공유하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
// ============================================================

/// 화면 단계가 끝난 뒤 무엇을 기다리는지 설명합니다.
///
/// 이 값은 서버 상태를 변경하지 않습니다. 화면 코드를 읽는 사람이 연출 완료와
/// 실제 게임 진행의 책임을 혼동하지 않도록 명시하는 클라이언트 표현 계약입니다.
enum GameFlowAdvancePolicy {
  /// 문구나 애니메이션 완료 콜백으로 다음 로컬 화면 연출을 시작합니다.
  clientPresentation,

  /// 클라이언트는 화면만 유지하고 Cloud Functions가 갱신한 서버 상태를 기다립니다.
  waitsForServer,

  /// 연출 완료 후 callable 명령을 보내고, 다음 서버 상태가 도착할 때까지 기다립니다.
  clientCallbackThenServer,
}

/// 휴대폰 단계에서 화면의 어느 영역을 보여 줄지 정하는 표현 설정입니다.
///
/// 게임 규칙이나 서버 명령 가능 여부를 결정하지 않습니다. 예를 들어
/// [showActions]가 true여도 실제 버튼 활성화 여부는 Controller의 `can...` 값을
/// 따라야 합니다. 이 객체는 복잡한 Widget 조건문을 `phone_board.dart`의 단계
/// 설정으로 끌어올려, 화면 구성을 한눈에 확인하고 수정하기 위한 용도입니다.
@immutable
class PhoneGameRegions {
  const PhoneGameRegions({
    this.showTopBar = false,
    this.showHand = false,
    this.showTimer = false,
    this.showActions = false,
  });

  /// 설정·룰북·퇴장 등이 있는 상단바 표시 여부입니다.
  final bool showTopBar;

  /// 플레이어 손패 또는 게임의 주 콘텐츠 표시 여부입니다.
  final bool showHand;

  /// 서버 마감 시각을 보여 주는 타이머 표시 여부입니다.
  final bool showTimer;

  /// 카드 제출·CALL·FOLD 등 조작 영역 표시 여부입니다.
  final bool showActions;
}

/// 한 화면 단계에서 실행하는 애니메이션의 이름과 재생시간입니다.
///
/// [enabled]를 false로 바꾸면 해당 단계의 선택적 연출을 생략할 수 있습니다.
/// 단, 카드 공개 완료처럼 서버 명령을 보내는 경계 연출은 호출부가 완료 콜백을
/// 대신 실행하도록 구현되어 있어야 합니다.
@immutable
class GameFlowAnimationConfig {
  const GameFlowAnimationConfig({
    required this.duration,
    this.widget,
    this.name,
    this.enabled = true,
  });

  const GameFlowAnimationConfig.disabled()
    : widget = null,
      name = null,
      duration = Duration.zero,
      enabled = false;

  /// 이 단계를 그리는 위젯의 타입입니다.
  ///
  /// **문자열 [name] 대신 이것을 쓰세요.** 위젯 이름이 바뀌거나 사라지면
  /// 컴파일 오류가 납니다. 문자열은 위젯을 갈아끼워도 옛 이름을 그대로 들고
  /// 있어서 설정이 조용히 거짓말을 합니다.
  ///
  /// IDE에서 클릭하면 해당 위젯으로 바로 이동합니다.
  final Type? widget;

  /// 위젯 하나로 가리킬 수 없을 때만 쓰는 설명용 이름입니다.
  ///
  /// 예: 여러 위젯이 얽힌 전환 연출. 되도록 [widget]을 쓰세요.
  final String? name;

  /// 이 연출의 **총** 재생시간입니다. 실제 애니메이션 위젯에 그대로 전달됩니다.
  ///
  /// 위젯 내부의 개별 요소 curve·interval은 여기서 다루지 않습니다. 그것까지
  /// 끌어올리면 조율판이 파라미터 목록이 되어 '한눈에'가 깨집니다.
  final Duration duration;

  final bool enabled;

  /// 로그·진단 화면에 쓰는 표시 이름입니다.
  String get label => widget?.toString() ?? name ?? '없음';
}

/// 하나의 클라이언트 화면 단계를 설명하는 불변 설정입니다.
///
/// 서버의 `status`/`phase`를 이 객체가 직접 변경해서는 안 됩니다. [stage]는 이미
/// 화면 진입점에서 번역된 typed enum이고, 이 객체는 그 단계에서 보여줄 화면·문구·
/// 애니메이션과 시간값만 관리합니다.
@immutable
class GameFlowStep<TStage extends Enum> {
  const GameFlowStep({
    required this.stage,
    required this.showScreen,
    required this.advancePolicy,
    this.showAnnouncement = false,
    this.announcementId,
    this.announcementKind = GameAnnouncementKind.transient,
    this.announcement,
    this.announcementTone = GameAnnouncementTone.neutral,
    this.announcementDuration = const Duration(milliseconds: 1900),
    this.animation = const GameFlowAnimationConfig.disabled(),
    this.beforeDelay = Duration.zero,
    this.afterDelay = Duration.zero,
    this.blocksInteraction = false,
    this.showScrim = false,
    this.description = '',
    this.screenWidget,
    this.sound,
    this.soundDelay = Duration.zero,
    this.sharedWith = const [],
    this.phoneRegions,
  }) : assert(
         !showAnnouncement || (announcementId != null && announcement != null),
         '문구를 표시하는 단계는 announcementId와 announcement가 필요합니다.',
       );

  /// 화면 진입점이 서버 상태를 번역한 클라이언트 단계입니다.
  final TStage stage;

  /// 이 단계에서 게임 Screen/Widget을 그릴지 여부입니다.
  final bool showScreen;

  /// 공용 안내 레이어에 문구를 표시할지 여부입니다.
  final bool showAnnouncement;
  final String? announcementId;
  final GameAnnouncementKind announcementKind;
  final String? announcement;
  final GameAnnouncementTone announcementTone;

  /// 문구가 화면에 유지되는 총 시간입니다.
  ///
  /// `gameStart`와 `round` 문구는 Fade/Scale 연출의 총 재생시간이기도 합니다.
  final Duration announcementDuration;

  /// 이 단계의 대표 애니메이션 설정입니다.
  final GameFlowAnimationConfig animation;

  /// 이 단계가 끝난 뒤 클라이언트와 서버 중 어느 쪽을 기다리는지 나타냅니다.
  final GameFlowAdvancePolicy advancePolicy;

  /// 화면 또는 연출을 시작하기 전에 기다리는 시간입니다.
  final Duration beforeDelay;

  /// 화면 또는 연출이 끝난 뒤 다음 로컬 동작 전에 기다리는 시간입니다.
  final Duration afterDelay;

  /// 단계가 진행되는 동안 하위 게임 UI 입력을 막아야 하는지 여부입니다.
  ///
  /// [GameAnnouncement] 레이어 자체는 안내 문구 표시 전용이라 포인터를 가로채지
  /// 않습니다. true인 단계는 셸이 게임 화면을 숨기거나 상위 화면이 입력을 막아야
  /// 하며, 이 구분을 없애면 카드 분배 중 중복 명령이 전송될 수 있습니다.
  final bool blocksInteraction;

  /// 문구 뒤의 게임 화면을 어둡게 표시할지 여부입니다.
  final bool showScrim;

  /// 이 단계를 그리는 위젯의 타입입니다.
  ///
  /// 애니메이션이 없는 단계(결과 화면 등)도 무엇이 그려지는지 여기서 보입니다.
  /// 애니메이션 위젯이 따로 있으면 [GameFlowAnimationConfig.widget]에 둡니다.
  ///
  /// 위젯을 **생성**하지는 않습니다. 생성에 필요한 런타임 값(좌석 목록,
  /// 콜백 등)은 화면 코드가 갖고 있고, 여기는 '무엇이 그려지는가'만 가리킵니다.
  final Type? screenWidget;

  /// 이 단계가 무슨 단계인지 한 줄 설명입니다.
  ///
  /// 주석이 아니라 필드로 두는 이유는 **코드가 읽을 수 있어야** 하기 때문입니다.
  /// 개발 모드의 단계 목록 화면이 이 값을 그대로 보여 줍니다.
  final String description;

  /// 이 단계에 들어갈 때 재생할 효과음 경로입니다.
  ///
  /// null이면 이 단계는 소리를 내지 않습니다. 배경음악은 단계가 아니라 게임
  /// 전체의 수명주기를 따르므로 여기서 다루지 않습니다.
  final String? sound;

  /// 단계 진입 후 [sound]를 재생하기까지 기다리는 시간입니다.
  final Duration soundDelay;

  /// 이 단계의 위젯 **인스턴스**를 함께 쓰는 다른 단계들입니다.
  ///
  /// 단계가 바뀌어도 같은 위젯이 유지돼야 할 때 씁니다. 라이어스포커의 라운드
  /// 보드가 그렇습니다 — `roundStarting`에서 등장한 보드를 `playing` ·
  /// `cardsPlaying` · `cardsRevealing`에서도 **그대로** 씁니다.
  ///
  /// 여기에 적지 않고 단계마다 따로 선언하면 stage가 바뀔 때마다 위젯이 새로
  /// 만들어져, 카드를 낼 때마다 보드가 다시 등장합니다.
  ///
  /// 재생시간도 소유 단계의 값을 씁니다([GameFlowConfig.widgetOwnerOf]).
  final List<TStage> sharedWith;

  /// 휴대폰 화면에서 단계별로 표시할 영역입니다.
  ///
  /// 태블릿 단계에서는 null로 두며, 휴대폰에서도 null이면 기존 셸 기본 정책을
  /// 사용합니다. 값이 있으면 Screen은 이 설정을 기준으로 영역을 표시하되,
  /// 버튼 활성화 같은 게임 규칙은 반드시 Controller 값을 다시 확인해야 합니다.
  final PhoneGameRegions? phoneRegions;

  /// 이 단계의 문구 설정을 공용 [GameAnnouncement] 모델로 변환합니다.
  GameAnnouncement? buildAnnouncement() {
    if (!showAnnouncement) return null;
    return GameAnnouncement(
      id: announcementId!,
      kind: announcementKind,
      text: announcement!,
      tone: announcementTone,
      duration: announcementDuration,
      animate: animation.enabled,
      blocksInteraction: blocksInteraction,
      showScrim: showScrim,
    );
  }
}

/// 한 화면의 모든 단계를 typed enum으로 조회하는 불변 설정 모음입니다.
@immutable
class GameFlowConfig<TStage extends Enum> {
  const GameFlowConfig({required this.steps});

  final Map<TStage, GameFlowStep<TStage>> steps;

  GameFlowStep<TStage> stepFor(TStage stage) {
    final step = steps[stage];
    if (step == null) {
      throw StateError('$stage 단계의 GameFlowStep이 등록되지 않았습니다.');
    }
    return step;
  }

  /// [stage]를 그리는 위젯을 **소유한** 단계를 돌려줍니다.
  ///
  /// 보통은 자기 자신입니다. 다른 단계의 [GameFlowStep.sharedWith]에 들어 있는
  /// 단계라면 그 소유 단계를 돌려줍니다.
  ///
  /// 화면 코드는 재생시간과 key를 **소유 단계 기준으로** 잡아야 합니다. 현재
  /// 단계 값으로 덮으면 재접속했을 때 보드 속도가 달라집니다.
  GameFlowStep<TStage> widgetOwnerOf(TStage stage) {
    for (final step in steps.values) {
      if (step.sharedWith.contains(stage)) return step;
    }
    return stepFor(stage);
  }
}
