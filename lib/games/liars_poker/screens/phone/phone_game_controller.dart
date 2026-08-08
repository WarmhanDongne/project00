import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/gen/assets.gen.dart';

/// Realtime Database에 저장된 휴대폰 플레이어의 실제 카드입니다.
class PhoneHandCard {
  const PhoneHandCard({required this.id, required this.rank});

  final String id;
  final String rank;
}

class PhoneGamePlayer {
  const PhoneGamePlayer({
    required this.uid,
    required this.nickname,
    required this.status,
    required this.remainingCardCount,
  });

  final String uid;
  final String nickname;
  final String status;
  final int remainingCardCount;
}

/// 휴대폰의 공개 게임 상태와 개인 손패 구독, Cloud Function 명령을 관리합니다.
class PhoneGameController extends ChangeNotifier {
  PhoneGameController({
    required this.roomCode,
    required this.uid,
    required this.gameService,
  });

  final String roomCode;
  final String uid;
  final LiarsPokerService gameService;

  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _handSubscription;
  bool _hasPublicSnapshot = false;
  bool _hasHandSnapshot = false;

  String status = 'waiting';
  String phase = 'playing';
  String table = 'K';
  String? turnUid;
  String? winnerUid;
  String? penaltyTargetUid;
  String? lastPlayPlayerUid;
  int lastPlayCardCount = 0;
  int round = 1;
  int revision = 0;

  Map<String, PhoneGamePlayer> players = const {};
  List<PhoneHandCard> handCards = const [];

  /// 컨트롤러 알림마다 새 리스트를 만들지 않도록 손패 변경 때만 갱신합니다.
  List<AssetGenImage> handCardAssets = const [];

  bool isCommandInFlight = false;
  String? errorMessage;

  bool get isInitialLoading => !_hasPublicSnapshot || !_hasHandSnapshot;
  bool get isMyTurn => turnUid == uid;
  bool get isFinished => status == 'finished';
  bool get isEliminated => players[uid]?.status == 'eliminated';

  bool get canSelectCards =>
      status == 'playing' &&
      phase == 'playing' &&
      isMyTurn &&
      !isEliminated &&
      handCards.isNotEmpty;

  bool get canSubmitCards => canSelectCards && !isCommandInFlight;

  bool get canCallLiar =>
      status == 'playing' &&
      (phase == 'playing' || phase == 'lastCardChallenge') &&
      isMyTurn &&
      !isEliminated &&
      lastPlayPlayerUid != null &&
      !isCommandInFlight;

  bool get canPassLastCardChallenge =>
      status == 'playing' &&
      phase == 'lastCardChallenge' &&
      isMyTurn &&
      !isEliminated &&
      !isCommandInFlight;

  String get turnNickname => players[turnUid]?.nickname ?? '다른 플레이어';

  String get statusMessage {
    if (isFinished) {
      final winner = players[winnerUid]?.nickname;
      return winner == null ? '게임이 종료되었습니다' : '$winner님이 승리했습니다';
    }
    if (isEliminated) return '탈락했습니다';
    if (phase == 'dealing') return '태블릿에서 카드를 배분하는 중입니다';
    if (phase == 'penalty') {
      return penaltyTargetUid == uid ? '내 벌칙을 진행 중입니다' : '벌칙을 진행 중입니다';
    }
    if (phase == 'lastCardChallenge') {
      return isMyTurn ? '마지막 카드가 라이어인지 결정하세요' : '$turnNickname님의 결정을 기다리는 중';
    }
    return isMyTurn ? '내 차례 · 카드 1~3장을 제출하세요' : '$turnNickname님의 차례';
  }

  void initialize() {
    _publicSubscription?.cancel();
    _handSubscription?.cancel();

    _publicSubscription = gameService.query
        .watchPublicGame(roomCode)
        .listen(_handlePublicGame, onError: _handleSubscriptionError);
    _handSubscription = gameService.query
        .watchPrivateHand(roomCode: roomCode, uid: uid)
        .listen(_handleHand, onError: _handleSubscriptionError);
  }

  void _handlePublicGame(DatabaseEvent event) {
    final value = event.snapshot.value;

    if (value is! Map) {
      // 연결 직후의 빈 로컬 캐시는 방 삭제를 의미하지 않으므로 무시합니다.
      return;
    }

    _hasPublicSnapshot = true;

    final data = Map<Object?, Object?>.from(value);
    status = _string(data['status'], fallback: 'playing');
    phase = _string(data['phase'], fallback: 'playing');
    table = _string(data['table'], fallback: 'K').toUpperCase();
    turnUid = _nullableString(data['turnUid']);
    winnerUid = _nullableString(data['winnerUid']);
    penaltyTargetUid = _nullableString(data['penaltyTargetUid']);
    round = _integer(data['round']) ?? 1;
    revision = _integer(data['revision']) ?? revision;
    players = Map.unmodifiable(_parsePlayers(data['players']));

    final lastPlay = data['lastPlay'];
    if (lastPlay is Map) {
      final lastPlayData = Map<Object?, Object?>.from(lastPlay);
      lastPlayPlayerUid = _nullableString(lastPlayData['playerUid']);
      lastPlayCardCount = _integer(lastPlayData['cardCount']) ?? 0;
    } else {
      lastPlayPlayerUid = null;
      lastPlayCardCount = 0;
    }

    errorMessage = null;
    notifyListeners();
  }

  void _handleHand(DatabaseEvent event) {
    _hasHandSnapshot = true;
    final parsedCards = <PhoneHandCard>[];
    final value = event.snapshot.value;

    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;
        final cardData = Map<Object?, Object?>.from(entry.value as Map);
        final id = _nullableString(cardData['id']) ?? entry.key.toString();
        final rank = _nullableString(cardData['rank']);
        if (id.isEmpty || rank == null || rank.isEmpty) continue;
        parsedCards.add(PhoneHandCard(id: id, rank: rank.toUpperCase()));
      }
    }

    // RTDB Map의 순서에 의존하지 않고 카드 ID 기준으로 화면 순서를 고정합니다.
    parsedCards.sort((left, right) => left.id.compareTo(right.id));
    handCards = List.unmodifiable(parsedCards);
    handCardAssets = List.unmodifiable(
      parsedCards.map((card) => _cardAssetForRank(card.rank)),
    );
    notifyListeners();
  }

  Map<String, PhoneGamePlayer> _parsePlayers(Object? value) {
    if (value is! Map) return const {};

    final result = <String, PhoneGamePlayer>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final data = Map<Object?, Object?>.from(entry.value as Map);
      final uid = _nullableString(data['uid']) ?? entry.key.toString();
      result[uid] = PhoneGamePlayer(
        uid: uid,
        nickname: _string(data['nickname'], fallback: 'Player'),
        status: _string(data['status'], fallback: 'alive'),
        remainingCardCount: _integer(data['remainingCardCount']) ?? 0,
      );
    }
    return result;
  }

  Future<bool> submitCardIndexes(List<int> indexes) async {
    if (!canSubmitCards || indexes.isEmpty || indexes.length > 3) {
      return _reject('현재 카드를 제출할 수 없습니다.');
    }

    final cardIds = <String>[];
    for (final index in indexes) {
      if (index < 0 || index >= handCards.length) {
        return _reject('선택한 카드 정보가 바뀌었습니다. 다시 선택해주세요.');
      }
      cardIds.add(handCards[index].id);
    }

    return _runCommand(
      () =>
          gameService.command.submitCards(roomCode: roomCode, cardIds: cardIds),
    );
  }

  Future<bool> callLiar() {
    if (!canCallLiar) return Future.value(_reject('현재 라이어를 선언할 수 없습니다.'));
    return _runCommand(() => gameService.command.callLiar(roomCode: roomCode));
  }

  Future<bool> passLastCardChallenge() {
    if (!canPassLastCardChallenge) {
      return Future.value(_reject('현재 마지막 카드 도전을 통과할 수 없습니다.'));
    }
    return _runCommand(
      () => gameService.command.passLastCardChallenge(roomCode: roomCode),
    );
  }

  Future<bool> _runCommand(
    Future<Map<String, dynamic>> Function() command,
  ) async {
    if (isCommandInFlight) return false;

    isCommandInFlight = true;
    errorMessage = null;
    notifyListeners();

    try {
      await command();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isCommandInFlight = false;
      notifyListeners();
    }
  }

  bool _reject(String message) {
    errorMessage = message;
    notifyListeners();
    return false;
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  void _handleSubscriptionError(Object error) {
    errorMessage = '게임 정보를 불러오지 못했습니다: $error';
    notifyListeners();
  }

  String _string(Object? value, {required String fallback}) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String? _nullableString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _integer(Object? value) {
    return value is int ? value : (value is num ? value.toInt() : null);
  }

  AssetGenImage _cardAssetForRank(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.cards.whiteA,
      'K' => Assets.games.liarsPoker.images.cards.whiteK,
      'Q' => Assets.games.liarsPoker.images.cards.whiteQ,
      'JOKER' => Assets.games.liarsPoker.images.cards.whiteJoker,
      _ => Assets.games.liarsPoker.images.cards.whiteBack,
    };
  }

  @override
  void dispose() {
    _publicSubscription?.cancel();
    _handSubscription?.cancel();
    super.dispose();
  }
}
