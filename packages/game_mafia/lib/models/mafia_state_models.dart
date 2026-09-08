import 'package:flutter/foundation.dart';

//=======================서버 공개 상태의 하위 객체==============================
// 서버(`functions/src/mafia/types.ts`)가 보내는 값을 그대로 옮겨 담습니다.
// **여기서 규칙을 다시 계산하지 마세요.** 조사 결과·승패·신분은 서버가 판정한
// 값을 그대로 써야 밀러·마피아 보스처럼 보이는 진영이 다른 역할이 어긋나지
// 않습니다.

/// 아침 발표에 쓰는 밤 결과입니다.
@immutable
class MafiaMorningResult {
  const MafiaMorningResult({
    required this.deadUids,
    required this.savedCount,
    this.endsGame = false,
    this.exposedUid,
  });

  /// 밤에 사망한 사람입니다. 비어 있으면 아무도 죽지 않았습니다.
  final List<String> deadUids;

  /// 보호로 살아난 사람 수입니다.
  ///
  /// **누가 살렸는지·누가 살아났는지는 서버가 보내지 않습니다.** 의사와 대상이
  /// 드러나기 때문입니다.
  final int savedCount;

  /// 이 발표가 끝나면 게임이 끝나는지입니다(서버가 알려 주는 힌트).
  ///
  /// 승패 판정은 서버가 합니다. 이 값은 발표 뒤에 **'토론을 시작합니다' 안내를
  /// 띄우지 않기 위한** 것입니다. 이미 끝난 판에서 다음 단계를 예고하면 게임이
  /// 계속되는 것처럼 보입니다.
  final bool endsGame;

  /// 기자가 취재에 성공해 **신분이 공개되는** 사람입니다.
  ///
  /// 공개된 신분 자체는 `revealedRoles`에 있습니다. 이 값은 아침 발표가 누구의
  /// 카드를 뒤집어 보여 줄지 알기 위한 것입니다. 없으면 취재가 없었거나
  /// 실패한 밤입니다.
  final String? exposedUid;

  factory MafiaMorningResult.fromMap(Map<Object?, Object?> map) {
    final exposedUid = map['exposedUid']?.toString();
    return MafiaMorningResult(
      deadUids: _stringList(map['deadUids']),
      savedCount: (map['savedCount'] as num?)?.toInt() ?? 0,
      endsGame: map['endsGame'] == true,
      exposedUid: (exposedUid == null || exposedUid.isEmpty)
          ? null
          : exposedUid,
    );
  }

  bool get hasDeaths => deadUids.isNotEmpty;

  /// 기자의 취재가 성공한 밤인지입니다.
  bool get hasExposure => exposedUid != null;
}

/// 밤 행동이 제출된 순간 태블릿이 낼 소리 신호입니다.
///
/// 확정(2026-08): 총성 같은 직업 효과음은 밤이 시작될 때 자동으로 울리지 않고,
/// 그 직업이 **선택을 완료한 순간** 방 가운데 태블릿에서 울립니다.
///
/// 서버는 **행동의 종류만** 보냅니다. 누가 했는지는 보내지 않습니다 — uid가
/// 오면 그 사람의 신분이 그대로 드러납니다.
@immutable
class MafiaNightActionCue {
  const MafiaNightActionCue({required this.id, required this.action});

  /// 신호 번호입니다. 이 값이 바뀔 때만 소리를 냅니다.
  ///
  /// 마감 전에 대상을 바꿔 다시 제출해도 그 밤에 한 번만 올라갑니다.
  final int id;

  /// 행동의 종류입니다(`eliminate`·`investigate`·`protect`…).
  ///
  /// [MafiaNightAction]의 이름과 같은 문자열입니다. 이 빌드가 모르는 행동이면
  /// 소리를 내지 않습니다.
  final String action;

  static MafiaNightActionCue? fromMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final id = (raw['id'] as num?)?.toInt();
    final action = raw['action'] as String?;
    if (id == null || id <= 0 || action == null) return null;
    return MafiaNightActionCue(id: id, action: action);
  }
}

/// 개표 결과입니다.
@immutable
class MafiaVoteResult {
  const MafiaVoteResult({
    required this.tally,
    required this.executedUid,
    required this.tie,
    required this.abstainCount,
    this.endsGame = false,
  });

  /// `대상 uid → 득표수`입니다. 누가 찍었는지는 서버가 보내지 않습니다.
  final Map<String, int> tally;

  /// 처형된 사람입니다. 동표로 무처형이면 null입니다.
  final String? executedUid;

  /// 동표로 무처형인지입니다.
  final bool tie;

  /// 기권(미투표) 인원입니다.
  final int abstainCount;

  /// 이 처형으로 게임이 끝나는지입니다(서버가 알려 주는 힌트).
  ///
  /// 승패 판정은 서버가 합니다. 이 값은 발표 뒤에 **'밤이 되었습니다' 안내를
  /// 띄우지 않기 위한** 것입니다.
  final bool endsGame;

  factory MafiaVoteResult.fromMap(Map<Object?, Object?> map) {
    final rawTally = map['tally'];
    final tally = <String, int>{};
    if (rawTally is Map) {
      for (final entry in rawTally.entries) {
        final count = (entry.value as num?)?.toInt();
        if (count != null) tally[entry.key.toString()] = count;
      }
    }
    return MafiaVoteResult(
      tally: Map.unmodifiable(tally),
      executedUid: map['executedUid']?.toString(),
      tie: map['tie'] == true,
      abstainCount: (map['abstainCount'] as num?)?.toInt() ?? 0,
      endsGame: map['endsGame'] == true,
    );
  }

  /// 득표수가 많은 순서로 정렬한 결과입니다. 태블릿 개표 연출이 씁니다.
  List<({String uid, int count})> get ranked {
    final entries =
        tally.entries
            .map((entry) => (uid: entry.key, count: entry.value))
            .toList()
          ..sort((left, right) => right.count.compareTo(left.count));
    return List.unmodifiable(entries);
  }
}

/// 경찰·탐정의 조사 기록 한 건입니다.
@immutable
class MafiaInvestigation {
  const MafiaInvestigation({
    required this.round,
    required this.targetUid,
    required this.verdict,
  });

  final int round;
  final String targetUid;

  /// 서버가 계산한 결과 문구입니다. 예: `마피아`·`시민`·상대가 찾아간 닉네임.
  final String verdict;

  factory MafiaInvestigation.fromMap(Map<Object?, Object?> map) {
    return MafiaInvestigation(
      round: (map['round'] as num?)?.toInt() ?? 0,
      targetUid: map['targetUid']?.toString() ?? '',
      verdict: map['verdict']?.toString() ?? '',
    );
  }
}

/// Realtime Database가 리스트를 Map으로 돌려주는 경우까지 함께 처리합니다.
List<String> _stringList(Object? value) {
  if (value is List) {
    return List.unmodifiable(value.map((item) => item.toString()));
  }
  if (value is Map) {
    return List.unmodifiable(value.values.map((item) => item.toString()));
  }
  return const <String>[];
}

/// 위 헬퍼를 다른 파일에서도 쓰기 위해 노출합니다.
List<String> mafiaStringList(Object? value) => _stringList(value);
