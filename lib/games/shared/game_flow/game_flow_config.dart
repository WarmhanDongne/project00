import 'package:flutter/foundation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';

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

/// 한 화면 단계에서 실행하는 애니메이션의 이름과 재생시간입니다.
///
/// [enabled]를 false로 바꾸면 해당 단계의 선택적 연출을 생략할 수 있습니다.
/// 단, 카드 공개 완료처럼 서버 명령을 보내는 경계 연출은 호출부가 완료 콜백을
/// 대신 실행하도록 구현되어 있어야 합니다.
@immutable
class GameFlowAnimationConfig {
  const GameFlowAnimationConfig({
    required this.name,
    required this.duration,
    this.enabled = true,
  });

  const GameFlowAnimationConfig.disabled()
    : name = '없음',
      duration = Duration.zero,
      enabled = false;

  final String name;
  final Duration duration;
  final bool enabled;
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
}
