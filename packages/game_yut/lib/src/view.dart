import 'package:flutter/foundation.dart';
import 'package:game_yut/src/rules.dart';

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};
List<Object?> _list(Object? value) => value is List
    ? value
    : value is Map
    ? (value.entries.toList()..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
          .map((entry) => entry.value)
          .toList()
    : const [];
int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

/// 청군·백군(전략)과 네 방향(일반) 팀 이름입니다.
enum YutTeam {
  blue,
  white,
  east,
  south,
  west,
  north;

  static YutTeam? fromWire(Object? value) {
    for (final team in values) {
      if (team.name == value) return team;
    }
    return null;
  }
}

@immutable
class YutPlayerView {
  const YutPlayerView({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.seatIndex,
    required this.team,
    required this.alive,
  });
  final String uid;
  final String nickname;
  final String characterId;
  final int seatIndex;
  final YutTeam? team;
  final bool alive;

  /// 말에 새기는 이름 첫 글자입니다.
  String get initial => nickname.trim().isEmpty
      ? '?'
      : String.fromCharCode(nickname.trim().runes.first);
}

@immutable
class YutPieceView {
  const YutPieceView({
    required this.owner,
    required this.id,
    required this.position,
    required this.path,
    required this.status,
  });
  final String owner;
  final int id;
  final int position;
  final List<int> path;
  final String status;

  bool get onBoard => status == 'onBoard';
  bool get ready => status == 'ready';
  bool get finished => status == 'finished';
}

@immutable
class YutChip {
  const YutChip(this.index, this.result);
  final int index;
  final YutResult result;
}

@immutable
class YutRollView {
  const YutRollView({
    required this.result,
    required this.stickUps,
    required this.actorUid,
    required this.revealed,
    required this.createdAt,
  });
  final YutResult result;
  final List<bool> stickUps;
  final String? actorUid;

  /// 전략 윷놀이에서 사람마다 고른 면입니다. true가 앞면입니다.
  final Map<String, bool> revealed;
  final int createdAt;

  int get frontCount => stickUps.where((up) => up).length;
}

@immutable
class YutMoveView {
  const YutMoveView({
    required this.owner,
    required this.pieceIds,
    required this.path,
    required this.result,
    required this.captured,
    required this.extraThrow,
    required this.createdAt,
  });
  final String owner;
  final List<int> pieceIds;
  final List<int> path;
  final YutResult? result;
  final Map<String, List<int>> captured;
  final bool extraThrow;
  final int createdAt;
}

/// 서버 공개 상태를 화면이 쓰기 좋은 형태로 바꾼 값입니다.
@immutable
class YutGameView {
  const YutGameView({
    required this.gameId,
    required this.status,
    required this.phase,
    required this.round,
    required this.turnUid,
    required this.turnTeam,
    required this.deadlineAt,
    required this.choiceCount,
    required this.players,
    required this.pieces,
    required this.pool,
    required this.lastRoll,
    required this.lastMove,
    required this.winnerUid,
    required this.winningTeam,
    required this.finishReason,
    required this.paused,
  });

  factory YutGameView.fromPublic(String gameId, Map<String, dynamic> pub) {
    final players = <String, YutPlayerView>{};
    _map(pub['players']).forEach((uid, raw) {
      final player = _map(raw);
      players[uid] = YutPlayerView(
        uid: uid,
        nickname: '${player['nickname'] ?? ''}',
        characterId: '${player['characterId'] ?? ''}',
        seatIndex: _int(player['seatIndex']),
        team: YutTeam.fromWire(player['team']),
        alive: player['status'] != 'eliminated',
      );
    });
    final pieces = <String, List<YutPieceView>>{};
    _map(pub['pieces']).forEach((owner, raw) {
      pieces[owner] = [
        for (final entry in _list(raw))
          if (entry is Map)
            YutPieceView(
              owner: owner,
              id: _int(_map(entry)['id']),
              position: _int(_map(entry)['position'], -1),
              path: _list(_map(entry)['path']).map((e) => _int(e)).toList(),
              status: '${_map(entry)['status'] ?? 'ready'}',
            ),
      ]..sort((a, b) => a.id.compareTo(b.id));
    });
    final pool = <YutChip>[];
    final rawPool = _list(pub['pool']);
    for (var i = 0; i < rawPool.length; i++) {
      final result = YutResult.fromWire(_map(rawPool[i])['name']);
      if (result != null) pool.add(YutChip(i, result));
    }
    final roll = _map(pub['lastRoll']);
    final rollResult = YutResult.fromWire(roll['name']);
    final move = _map(pub['lastMove']);
    return YutGameView(
      gameId: gameId,
      status: '${pub['status'] ?? ''}',
      phase: '${pub['phase'] ?? ''}',
      round: _int(pub['round'], 1),
      turnUid: pub['turnUid'] as String?,
      turnTeam: YutTeam.fromWire(pub['turnTeam']),
      deadlineAt: _int(pub['turnDeadlineAt']),
      choiceCount: _int(pub['choiceCount']),
      players: players,
      pieces: pieces,
      pool: pool,
      lastRoll: rollResult == null
          ? null
          : YutRollView(
              result: rollResult,
              stickUps: _list(roll['stickUps']).map((e) => e == true).toList(),
              actorUid: roll['actorUid'] as String?,
              revealed: _map(
                roll['revealedChoices'],
              ).map((uid, value) => MapEntry(uid, value == true)),
              createdAt: _int(roll['createdAt']),
            ),
      lastMove: move.isEmpty
          ? null
          : YutMoveView(
              owner: '${move['owner'] ?? ''}',
              pieceIds: _list(move['pieceIds']).map((e) => _int(e)).toList(),
              path: _list(move['path']).map((e) => _int(e, -1)).toList(),
              result: YutResult.fromWire(move['result']),
              captured: {
                for (final entry in _list(move['captured']))
                  '${_map(entry)['owner']}': _list(
                    _map(entry)['pieceIds'],
                  ).map((e) => _int(e)).toList(),
              },
              extraThrow: move['extraThrow'] == true,
              createdAt: _int(move['createdAt']),
            ),
      winnerUid: pub['winnerUid'] as String?,
      winningTeam: YutTeam.fromWire(pub['winningTeam']),
      finishReason: pub['finishReason'] as String?,
      paused: _map(pub['recovery'])['paused'] == true,
    );
  }

  final String gameId;
  final String status;
  final String phase;
  final int round;
  final String? turnUid;
  final YutTeam? turnTeam;
  final int deadlineAt;
  final int choiceCount;
  final Map<String, YutPlayerView> players;
  final Map<String, List<YutPieceView>> pieces;
  final List<YutChip> pool;
  final YutRollView? lastRoll;
  final YutMoveView? lastMove;
  final String? winnerUid;
  final YutTeam? winningTeam;
  final String? finishReason;
  final bool paused;

  bool get loaded => status.isNotEmpty;
  bool get strategy => gameId != 'yut';
  bool get edition => gameId == 'strategy_yut_edition';
  bool get finished => status == 'finished';
  bool get selecting => !finished && phase == 'selecting';
  bool get rolling => !finished && phase == 'rolling';
  bool get moving => !finished && phase == 'moving';

  List<YutPlayerView> get seated =>
      players.values.toList()
        ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

  List<YutPlayerView> teamPlayers(YutTeam team) =>
      seated.where((player) => player.team == team).toList();

  YutPlayerView? player(String? uid) => uid == null ? null : players[uid];

  /// 말 묶음의 주인 키입니다. 일반은 UID, 전략은 팀 이름입니다.
  String ownerKeyOf(String uid) =>
      strategy ? (players[uid]?.team?.name ?? '') : uid;

  String? get turnOwner => strategy ? turnTeam?.name : turnUid;

  List<YutPieceView> piecesOf(String? owner) =>
      owner == null ? const [] : pieces[owner] ?? const [];

  YutTeam? teamOfOwner(String owner) =>
      strategy ? YutTeam.fromWire(owner) : players[owner]?.team;

  /// 전략 윷놀이는 팀 말 4개 중 0·1번을 첫째, 2·3번을 둘째 팀원이 맡습니다.
  YutPlayerView? pieceKeeper(String owner, int pieceId) {
    if (!strategy) return players[owner];
    final team = YutTeam.fromWire(owner);
    if (team == null) return null;
    final members = teamPlayers(team);
    if (members.isEmpty) return null;
    return members[(pieceId ~/ 2).clamp(0, members.length - 1)];
  }

  int finishedCount(String owner) =>
      piecesOf(owner).where((piece) => piece.finished).length;
}
