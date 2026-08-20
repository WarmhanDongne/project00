import 'package:flutter/foundation.dart';

//=======================서버 공개 상태의 하위 객체==============================
// 서버(`functions/src/mafia/types.ts`)가 보내는 값을 그대로 옮겨 담습니다.
// **여기서 규칙을 다시 계산하지 마세요.** 조사 결과·승패·신분은 서버가 판정한
// 값을 그대로 써야 밀러·마피아 보스처럼 보이는 진영이 다른 역할이 어긋나지
// 않습니다.

/// 아침 발표에 쓰는 밤 결과입니다.
@immutable
class MafiaMorningResult {
  const MafiaMorningResult({required this.deadUids, required this.savedCount});

  /// 밤에 사망한 사람입니다. 비어 있으면 아무도 죽지 않았습니다.
  final List<String> deadUids;

  /// 보호로 살아난 사람 수입니다.
  ///
  /// **누가 살렸는지·누가 살아났는지는 서버가 보내지 않습니다.** 의사와 대상이
  /// 드러나기 때문입니다.
  final int savedCount;

  factory MafiaMorningResult.fromMap(Map<Object?, Object?> map) {
    return MafiaMorningResult(
      deadUids: _stringList(map['deadUids']),
      savedCount: (map['savedCount'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasDeaths => deadUids.isNotEmpty;
}

/// 개표 결과입니다.
@immutable
class MafiaVoteResult {
  const MafiaVoteResult({
    required this.tally,
    required this.executedUid,
    required this.tie,
    required this.abstainCount,
  });

  /// `대상 uid → 득표수`입니다. 누가 찍었는지는 서버가 보내지 않습니다.
  final Map<String, int> tally;

  /// 처형된 사람입니다. 동표로 무처형이면 null입니다.
  final String? executedUid;

  /// 동표로 무처형인지입니다.
  final bool tie;

  /// 기권(미투표) 인원입니다.
  final int abstainCount;

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
