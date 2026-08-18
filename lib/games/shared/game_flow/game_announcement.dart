import 'package:flutter/foundation.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

/// 화면 중앙 또는 고정 안내 슬롯에 표시할 문구의 의미입니다.
enum GameAnnouncementKind { gameStart, round, transient, persistent }

/// 문구의 의미 색상입니다. 실제 색은 렌더링 위젯의 스타일이 결정합니다.
enum GameAnnouncementTone { neutral, positive, negative }

/// 게임 상태에서 파생된 표시 데이터입니다.
///
/// 서버 응답 문자열이나 색상 같은 Flutter 표현 세부사항을 화면 곳곳에
/// 퍼뜨리지 않고, 모든 게임이 같은 안내 레이어에 이 값만 전달합니다.
@immutable
class GameAnnouncement {
  const GameAnnouncement({
    required this.id,
    required this.kind,
    required this.text,
    this.tone = GameAnnouncementTone.neutral,
    this.duration = const Duration(milliseconds: 1900),
    this.animate = true,
    this.blocksInteraction = false,
    this.showScrim = false,
  });

  const GameAnnouncement.gameStart({
    this.id = 'game-start',
    this.text = GameFlowCopy.gameStart,
    this.duration = const Duration(milliseconds: 1700),
  }) : kind = GameAnnouncementKind.gameStart,
       tone = GameAnnouncementTone.neutral,
       animate = true,
       blocksInteraction = true,
       showScrim = false;

  factory GameAnnouncement.round(
    int round, {
    String? id,
    Duration duration = const Duration(milliseconds: 1900),
  }) {
    return GameAnnouncement(
      id: id ?? 'round-$round',
      kind: GameAnnouncementKind.round,
      text: GameFlowCopy.round(round),
      duration: duration,
      blocksInteraction: true,
    );
  }

  factory GameAnnouncement.transient({
    required String id,
    required String text,
    GameAnnouncementTone tone = GameAnnouncementTone.neutral,
    Duration duration = const Duration(milliseconds: 1900),
    bool blocksInteraction = false,
    bool showScrim = false,
  }) {
    return GameAnnouncement(
      id: id,
      kind: GameAnnouncementKind.transient,
      text: text,
      tone: tone,
      duration: duration,
      blocksInteraction: blocksInteraction,
      showScrim: showScrim,
    );
  }

  factory GameAnnouncement.persistent({
    required String id,
    required String text,
    GameAnnouncementTone tone = GameAnnouncementTone.neutral,
    bool blocksInteraction = false,
    bool showScrim = false,
  }) {
    return GameAnnouncement(
      id: id,
      kind: GameAnnouncementKind.persistent,
      text: text,
      tone: tone,
      blocksInteraction: blocksInteraction,
      showScrim: showScrim,
    );
  }

  final String id;
  final GameAnnouncementKind kind;
  final String text;
  final GameAnnouncementTone tone;
  final Duration duration;

  /// false이면 Fade/Scale 없이 문구를 정적으로 유지합니다.
  ///
  /// 유지시간이 끝나면 애니메이션을 사용한 경우와 동일하게 완료 콜백을
  /// 호출하므로, 연출을 꺼도 화면 단계가 멈추지 않습니다.
  final bool animate;
  final bool blocksInteraction;
  final bool showScrim;
}
