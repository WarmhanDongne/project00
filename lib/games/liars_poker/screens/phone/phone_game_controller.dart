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
    required this.profileImageUrl,
    required this.status,
    required this.remainingCardCount,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final String status;
  final int remainingCardCount;
}

/// 서버가 공개한 최근 룰렛 결과입니다.
class PhonePenaltyResult {
  const PhonePenaltyResult({
    required this.targetUid,
    required this.result,
    required this.resolvedAt,
  });

  final String targetUid;
  final String result;
  final int resolvedAt;
}

/// 휴대폰의 공개 게임 상태와 개인 손패 구독, Cloud Function 명령을 관리합니다.
class PhoneGameController extends ChangeNotifier {
  static const int _cardsPerNewHand = 5;

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
  String? _lastDealtHandSignature;

  String status = 'waiting';
  String? finishReason;
  String phase = 'playing';
  String table = 'K';
  String? turnUid;
  String? winnerUid;
  String? penaltyTargetUid;
  String? lastPlayPlayerUid;
  String? lastPlayId;
  bool lastPlayRevealed = false;
  int lastPlayCardCount = 0;
  int round = 1;
  int revision = 0;
  int? turnDeadlineAt;

  Map<String, PhoneGamePlayer> players = const {};
  List<PhoneHandCard> handCards = const [];

  /// 컨트롤러 알림마다 새 리스트를 만들지 않도록 손패 변경 때만 갱신합니다.
  List<AssetGenImage> handCardAssets = const [];

  bool isCommandInFlight = false;
  bool hasRevealedHand = false;

  /// 새로운 5장 손패가 실제로 도착할 때마다 증가합니다.
  ///
  /// 라운드 번호가 다시 1부터 시작하는 게임 재시작에서도 손패 위젯을 새로
  /// 만들 수 있도록 화면의 key에는 [round] 대신 이 값을 사용합니다.
  int handDealVersion = 0;
  String? errorMessage;
  String? liarVerdictMessage;
  bool liarVerdictIsFalse = false;
  Timer? _liarVerdictTimer;
  PhonePenaltyResult? penaltyResult;
  bool isPenaltyResultVisible = false;
  Timer? _penaltyResultTimer;
  String? _activePenaltyResultKey;

  bool get isInitialLoading => !_hasPublicSnapshot || !_hasHandSnapshot;
  bool get isMyTurn => turnUid == uid;
  bool get isFinished => status == 'finished';
  bool get isNaturalResult =>
      isFinished &&
      winnerUid != null &&
      (finishReason == null || finishReason == 'winner');
  bool get isEliminated => players[uid]?.status == 'eliminated';
  int get alivePlayerCount =>
      players.values.where((player) => player.status == 'alive').length;

  bool get showPenaltyHandOverlay =>
      liarVerdictMessage != null ||
      (status == 'playing' && phase == 'penalty') ||
      isPenaltyResultVisible;
  PhoneGamePlayer? get penaltyStatusPlayer {
    final targetUid = isPenaltyResultVisible
        ? penaltyResult?.targetUid
        : penaltyTargetUid;
    return players[targetUid];
  }

  String? get visiblePenaltyResult =>
      isPenaltyResultVisible ? penaltyResult?.result : null;

  /// 공개 상태 기준으로 현재 플레이어가 이번 라운드의 패를 모두 냈는지입니다.
  bool get hasSubmittedAllCards =>
      !isEliminated && players[uid]?.remainingCardCount == 0;

  /// 패를 모두 낸 휴대폰에 표시할 중앙 대기 문구입니다.
  String? get emptyHandWaitingMessage {
    if (!hasSubmittedAllCards || phase == 'penalty' || isFinished) return null;
    return lastPlayPlayerUid == uid ? '상대의 선택을 기다리는 중...' : '다음 라운드를 기다려주세요';
  }

  /// 2명만 남은 마지막 카드 선택 단계에서 남은 플레이어가 보는 안내입니다.
  bool get showTwoPlayerPassPrompt =>
      alivePlayerCount == 2 &&
      phase == 'lastCardChallenge' &&
      isMyTurn &&
      lastPlayPlayerUid != null &&
      lastPlayPlayerUid != uid;

  bool get canSelectCards =>
      status == 'playing' &&
      phase == 'playing' &&
      !isEliminated &&
      handCards.isNotEmpty;

  bool get canSubmitCards => canSelectCards && isMyTurn && !isCommandInFlight;

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

  String? get statusMessage {
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
    return null;
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

    final hadPublicSnapshot = _hasPublicSnapshot;
    final data = Map<Object?, Object?>.from(value);
    final nextStatus = _string(data['status'], fallback: 'playing');
    final nextFinishReason = _nullableString(data['finishReason']);
    final nextPhase = _string(data['phase'], fallback: 'playing');
    final nextTable = _string(data['table'], fallback: 'K').toUpperCase();
    final nextTurnUid = _nullableString(data['turnUid']);
    final nextWinnerUid = _nullableString(data['winnerUid']);
    final nextPenaltyTargetUid = _nullableString(data['penaltyTargetUid']);
    final nextRound = _integer(data['round']) ?? 1;
    final nextRevision = _integer(data['revision']) ?? revision;
    final nextTurnDeadlineAt = _integer(data['turnDeadlineAt']);
    final nextPenaltyResult = _parsePenaltyResult(data['penaltyResult']);
    final Map<String, PhoneGamePlayer> nextPlayers = Map.unmodifiable(
      _parsePlayers(data['players']),
    );

    final lastPlay = data['lastPlay'];
    String? nextLastPlayId;
    String? nextLastPlayPlayerUid;
    var nextLastPlayRevealed = false;
    var nextLastPlayCardCount = 0;
    var nextActualRanks = const <String>[];
    if (lastPlay is Map) {
      final lastPlayData = Map<Object?, Object?>.from(lastPlay);
      nextLastPlayId = _nullableString(lastPlayData['playId']);
      nextLastPlayPlayerUid = _nullableString(lastPlayData['playerUid']);
      nextLastPlayRevealed = lastPlayData['revealed'] == true;
      nextLastPlayCardCount = _integer(lastPlayData['cardCount']) ?? 0;
      nextActualRanks = _stringList(lastPlayData['actualRanks']);
    }

    final didRevealLiarCards =
        _hasPublicSnapshot &&
        nextPhase == 'penalty' &&
        nextLastPlayRevealed &&
        (lastPlayId != nextLastPlayId || !lastPlayRevealed);
    final declarationWasFalse = nextActualRanks.any(
      (rank) => rank != nextTable && rank != 'JOKER',
    );
    final nextLiarVerdictMessage = didRevealLiarCards
        ? declarationWasFalse
              ? '허위 선언입니다'
              : '진실 선언입니다'
        : nextPhase == 'penalty'
        ? liarVerdictMessage
        : null;
    final nextLiarVerdictIsFalse = didRevealLiarCards
        ? declarationWasFalse
        : nextPhase == 'penalty' && liarVerdictIsFalse;

    final shouldResetReveal =
        nextPhase == 'dealing' && (phase != 'dealing' || round != nextRound);
    final nextHasRevealedHand = shouldResetReveal ? false : hasRevealedHand;
    final playersChanged = !_samePlayers(players, nextPlayers);
    final hasChanged =
        !_hasPublicSnapshot ||
        status != nextStatus ||
        finishReason != nextFinishReason ||
        phase != nextPhase ||
        table != nextTable ||
        turnUid != nextTurnUid ||
        winnerUid != nextWinnerUid ||
        penaltyTargetUid != nextPenaltyTargetUid ||
        !_samePenaltyResult(penaltyResult, nextPenaltyResult) ||
        round != nextRound ||
        turnDeadlineAt != nextTurnDeadlineAt ||
        lastPlayPlayerUid != nextLastPlayPlayerUid ||
        lastPlayId != nextLastPlayId ||
        lastPlayRevealed != nextLastPlayRevealed ||
        lastPlayCardCount != nextLastPlayCardCount ||
        liarVerdictMessage != nextLiarVerdictMessage ||
        liarVerdictIsFalse != nextLiarVerdictIsFalse ||
        hasRevealedHand != nextHasRevealedHand ||
        playersChanged ||
        errorMessage != null;

    _hasPublicSnapshot = true;
    status = nextStatus;
    finishReason = nextFinishReason;
    phase = nextPhase;
    table = nextTable;
    turnUid = nextTurnUid;
    winnerUid = nextWinnerUid;
    penaltyTargetUid = nextPenaltyTargetUid;
    penaltyResult = nextPenaltyResult;
    round = nextRound;
    revision = nextRevision;
    turnDeadlineAt = nextTurnDeadlineAt;
    players = playersChanged ? nextPlayers : players;
    lastPlayId = nextLastPlayId;
    lastPlayPlayerUid = nextLastPlayPlayerUid;
    lastPlayRevealed = nextLastPlayRevealed;
    lastPlayCardCount = nextLastPlayCardCount;
    liarVerdictMessage = nextLiarVerdictMessage;
    liarVerdictIsFalse = nextLiarVerdictIsFalse;
    hasRevealedHand = nextHasRevealedHand;
    errorMessage = null;

    if (didRevealLiarCards) {
      _liarVerdictTimer?.cancel();
      // 태블릿 공개 애니메이션(약 0.9초)과 이후 3초 판정 대기 시간 동안
      // 휴대폰 카드 영역에 판정 문구를 유지합니다.
      _liarVerdictTimer = Timer(const Duration(milliseconds: 3900), () {
        if (phase != 'penalty' || liarVerdictMessage == null) return;
        liarVerdictMessage = null;
        liarVerdictIsFalse = false;
        notifyListeners();
      });
    } else if (nextPhase != 'penalty') {
      _liarVerdictTimer?.cancel();
      _liarVerdictTimer = null;
    }

    _syncPenaltyResultVisibility(
      nextPenaltyResult,
      showFullDuration: hadPublicSnapshot,
    );
    if (hasChanged) notifyListeners();
  }

  void _handleHand(DatabaseEvent event) {
    final hadHandSnapshot = _hasHandSnapshot;
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

    // 카드 배분 단계와 개인 손패 이벤트의 도착 순서는 기기마다 달라질 수
    // 있습니다. 따라서 공개 상태는 phase가 아니라 실제 새 5장 카드 ID를
    // 기준으로 초기화합니다. 카드 제출로 4장 이하가 되는 변화에는 반응하지
    // 않으므로 펼친 상태가 유지됩니다.
    var dealVersionChanged = false;
    if (parsedCards.length == _cardsPerNewHand) {
      final dealtHandSignature = parsedCards.map((card) => card.id).join('|');
      if (dealtHandSignature != _lastDealtHandSignature) {
        _lastDealtHandSignature = dealtHandSignature;
        hasRevealedHand = false;
        handDealVersion += 1;
        dealVersionChanged = true;
      }
    }

    final handChanged = !_sameHandCards(handCards, parsedCards);
    if (handChanged) {
      handCards = List.unmodifiable(parsedCards);
      handCardAssets = List.unmodifiable(
        parsedCards.map((card) => _cardAssetForRank(card.rank)),
      );
    }

    // 연결 복구 과정에서 동일한 snapshot이 다시 도착하면 카드 위젯과 선택
    // 상태를 그대로 유지합니다. 최초 빈 손패 수신은 로딩 종료를 위해 알립니다.
    if (!handChanged && hadHandSnapshot && !dealVersionChanged) return;
    notifyListeners();
  }

  bool _sameHandCards(List<PhoneHandCard> left, List<PhoneHandCard> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].rank != right[index].rank) {
        return false;
      }
    }
    return true;
  }

  bool _samePlayers(
    Map<String, PhoneGamePlayer> left,
    Map<String, PhoneGamePlayer> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (final entry in left.entries) {
      final other = right[entry.key];
      final player = entry.value;
      if (other == null ||
          player.uid != other.uid ||
          player.nickname != other.nickname ||
          player.profileImageUrl != other.profileImageUrl ||
          player.status != other.status ||
          player.remainingCardCount != other.remainingCardCount) {
        return false;
      }
    }
    return true;
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
        profileImageUrl: _string(data['profileImageUrl'], fallback: ''),
        status: _string(data['status'], fallback: 'alive'),
        remainingCardCount: _integer(data['remainingCardCount']) ?? 0,
      );
    }
    return result;
  }

  PhonePenaltyResult? _parsePenaltyResult(Object? value) {
    if (value is! Map) return null;
    final data = Map<Object?, Object?>.from(value);
    final targetUid = _nullableString(data['targetUid']);
    final result = _nullableString(data['result']);
    final resolvedAt = _integer(data['resolvedAt']);
    if (targetUid == null ||
        result == null ||
        (result != 'safe' && result != 'eliminated') ||
        resolvedAt == null) {
      return null;
    }
    return PhonePenaltyResult(
      targetUid: targetUid,
      result: result,
      resolvedAt: resolvedAt,
    );
  }

  bool _samePenaltyResult(PhonePenaltyResult? left, PhonePenaltyResult? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return left.targetUid == right.targetUid &&
        left.result == right.result &&
        left.resolvedAt == right.resolvedAt;
  }

  void _syncPenaltyResultVisibility(
    PhonePenaltyResult? result, {
    required bool showFullDuration,
  }) {
    if (result == null) {
      _penaltyResultTimer?.cancel();
      _penaltyResultTimer = null;
      _activePenaltyResultKey = null;
      isPenaltyResultVisible = false;
      return;
    }

    final resultKey = '${result.targetUid}-${result.resolvedAt}';
    if (_activePenaltyResultKey == resultKey) return;
    _activePenaltyResultKey = resultKey;
    _penaltyResultTimer?.cancel();

    final elapsed = DateTime.now().millisecondsSinceEpoch - result.resolvedAt;
    final remainingMilliseconds = showFullDuration
        ? 3000
        : (3000 - elapsed).clamp(0, 3000).toInt();
    if (remainingMilliseconds <= 0) {
      isPenaltyResultVisible = false;
      return;
    }

    isPenaltyResultVisible = true;
    _penaltyResultTimer = Timer(
      Duration(milliseconds: remainingMilliseconds),
      () {
        isPenaltyResultVisible = false;
        _penaltyResultTimer = null;
        notifyListeners();
      },
    );
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

    if (isCommandInFlight) return false;

    isCommandInFlight = true;
    errorMessage = null;
    notifyListeners();

    try {
      await gameService.command.submitCards(
        roomCode: roomCode,
        cardIds: cardIds,
      );
      return true;
    } catch (_) {
      // Callable 응답만 유실됐을 수 있으므로 RTDB 개인 손패에서 제출 카드가
      // 제거됐는지 잠시 확인합니다. 서버 재시도와 상태 확인까지 모두 실패한
      // 경우에만 손패 위젯에 false를 반환해 카드 복귀를 실행합니다.
      if (await _waitForSubmittedCardsToDisappear(cardIds)) return true;
      errorMessage = '카드 제출 실패';
      return false;
    } finally {
      isCommandInFlight = false;
      notifyListeners();
    }
  }

  Future<bool> _waitForSubmittedCardsToDisappear(List<String> cardIds) async {
    final submittedIds = cardIds.toSet();
    for (var attempt = 0; attempt < 6; attempt += 1) {
      final remainingIds = handCards.map((card) => card.id).toSet();
      if (submittedIds.every((cardId) => !remainingIds.contains(cardId))) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    return false;
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

  /// 방향 전환 뒤에도 같은 라운드의 공개된 손패 상태를 유지합니다.
  void markHandRevealed() {
    hasRevealedHand = true;
    if (isMyTurn && phase == 'playing') {
      unawaited(gameService.command.readyTurn(roomCode: roomCode));
    }
  }

  void _handleSubscriptionError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('firebase_database/unknown') ||
        message.contains('stacktrace:')) {
      // RTDB 스트림은 연결 복구 후 최신 값을 다시 전달하므로 게임 화면을
      // 긴 네이티브 Stacktrace로 덮지 않고 기존 상태를 유지합니다.
      return;
    }
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

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((rank) => rank.toUpperCase())
        .toList(growable: false);
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
    _liarVerdictTimer?.cancel();
    _penaltyResultTimer?.cancel();
    _publicSubscription?.cancel();
    _handSubscription?.cancel();
    super.dispose();
  }
}
