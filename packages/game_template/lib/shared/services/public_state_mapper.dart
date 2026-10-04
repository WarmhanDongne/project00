// [public_state_mapper.dart] 새 게임의 RTDB 공개 snapshot을 화면 상태에 필요한
// 값으로 변환하는 예시입니다. 순수 변환만 두고 구독과 상태 발행은 controller가 담당합니다.

import 'package:game_kit/recovery/models/game_interruption.dart';

class TemplatePublicSnapshot {
  const TemplatePublicSnapshot({
    required this.status,
    required this.phase,
    required this.round,
    required this.revision,
    required this.interruption,
  });

  factory TemplatePublicSnapshot.fromValue(
    Object? value, {
    required String fallbackStatus,
    required String fallbackPhase,
    required int fallbackRound,
    required int fallbackRevision,
  }) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    final rawInterruption = map['interruption'];
    return TemplatePublicSnapshot(
      status: map['status']?.toString() ?? fallbackStatus,
      phase: map['phase']?.toString() ?? fallbackPhase,
      round: (map['round'] as num?)?.toInt() ?? fallbackRound,
      revision: (map['revision'] as num?)?.toInt() ?? fallbackRevision,
      interruption: rawInterruption is Map
          ? GameInterruption.fromMap(
              Map<Object?, Object?>.from(rawInterruption),
            )
          : null,
    );
  }

  final String status;
  final String phase;
  final int round;
  final int revision;
  final GameInterruption? interruption;
}
