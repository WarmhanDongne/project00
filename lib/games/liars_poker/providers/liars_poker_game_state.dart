import 'package:flutter/foundation.dart';
import 'package:project00/games/liars_poker/models/liars_poker_models.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';
import 'package:project00/gen/assets.gen.dart';

const Object _notProvided = Object();

//=======================Liar's Poker 불변 게임 상태==============================
/// Realtime Database 공개 상태, 개인 손패, 명령 실행 상태를 한 시점의
/// 스냅샷으로 표현합니다. Final Call처럼 휴대폰과 태블릿이 같은 상태를
/// 구독하며, 태블릿 전용 연출 상태(stage, 카드 더미 버전 등)는 여기 두지 않고
/// 태블릿 화면 State가 소유합니다.
@immutable
class LiarsPokerGameState {
  const LiarsPokerGameState({
    required this.status,
    required this.finishReason,
    required this.phase,
    required this.table,
    required this.turnUid,
    required this.winnerUid,
    required this.penaltyTargetUid,
    required this.lastPlayPlayerUid,
    required this.lastPlayId,
    required this.lastPlayRevealed,
    required this.lastPlayCardCount,
    required this.round,
    required this.revision,
    required this.turnDeadlineAt,
    required this.players,
    required this.roundPlays,
    required this.handCards,
    required this.handCardAssets,
    required this.isCommandInFlight,
    required this.isMenuCommandInFlight,
    required this.isResolvingPenalty,
    required this.rouletteRetry,
    required this.hasRevealedHand,
    required this.handDealVersion,
    required this.errorMessage,
    required this.liarVerdictMessage,
    required this.liarVerdictIsFalse,
    required this.isLiarVerdictPending,
    required this.penaltyResult,
    required this.isPenaltyResultVisible,
    required this.interruption,
  });

  factory LiarsPokerGameState.initial() => const LiarsPokerGameState(
    status: 'waiting',
    finishReason: null,
    phase: 'playing',
    table: 'K',
    turnUid: null,
    winnerUid: null,
    penaltyTargetUid: null,
    lastPlayPlayerUid: null,
    lastPlayId: null,
    lastPlayRevealed: false,
    lastPlayCardCount: 0,
    round: 1,
    revision: 0,
    turnDeadlineAt: null,
    players: <String, PhoneGamePlayer>{},
    roundPlays: <PublicLastPlay>[],
    handCards: <PhoneHandCard>[],
    handCardAssets: <AssetGenImage>[],
    isCommandInFlight: false,
    isMenuCommandInFlight: false,
    isResolvingPenalty: false,
    rouletteRetry: 0,
    hasRevealedHand: false,
    handDealVersion: 0,
    errorMessage: null,
    liarVerdictMessage: null,
    liarVerdictIsFalse: false,
    isLiarVerdictPending: false,
    penaltyResult: null,
    isPenaltyResultVisible: false,
    interruption: null,
  );

  final String status;
  final String? finishReason;
  final String phase;
  final String table;
  final String? turnUid;
  final String? winnerUid;
  final String? penaltyTargetUid;
  final String? lastPlayPlayerUid;
  final String? lastPlayId;
  final bool lastPlayRevealed;
  final int lastPlayCardCount;
  final int round;
  final int revision;
  final int? turnDeadlineAt;
  final Map<String, PhoneGamePlayer> players;

  /// 이번 라운드의 제출 목록(원본)입니다. 태블릿 중앙 카드 더미의 근거입니다.
  final List<PublicLastPlay> roundPlays;

  final List<PhoneHandCard> handCards;
  final List<AssetGenImage> handCardAssets;
  final bool isCommandInFlight;

  /// 태블릿 설정 메뉴(재시작/종료)와 중단 처리 명령의 실행 상태입니다.
  /// 게임 조작 명령([isCommandInFlight])과 분리해 서로 잠그지 않습니다.
  final bool isMenuCommandInFlight;

  /// 룰렛 결과를 서버에 전달하는 중인지 여부입니다.
  final bool isResolvingPenalty;

  /// 룰렛 결과 전달이 실패한 횟수입니다. 룰렛 위젯을 새로 만들 때 씁니다.
  final int rouletteRetry;

  final bool hasRevealedHand;
  final int handDealVersion;
  final String? errorMessage;
  final String? liarVerdictMessage;
  final bool liarVerdictIsFalse;
  final bool isLiarVerdictPending;
  final PhonePenaltyResult? penaltyResult;
  final bool isPenaltyResultVisible;
  final GameInterruption? interruption;

  LiarsPokerGameState copyWith({
    String? status,
    Object? finishReason = _notProvided,
    String? phase,
    String? table,
    Object? turnUid = _notProvided,
    Object? winnerUid = _notProvided,
    Object? penaltyTargetUid = _notProvided,
    Object? lastPlayPlayerUid = _notProvided,
    Object? lastPlayId = _notProvided,
    bool? lastPlayRevealed,
    int? lastPlayCardCount,
    int? round,
    int? revision,
    Object? turnDeadlineAt = _notProvided,
    Map<String, PhoneGamePlayer>? players,
    List<PublicLastPlay>? roundPlays,
    List<PhoneHandCard>? handCards,
    List<AssetGenImage>? handCardAssets,
    bool? isCommandInFlight,
    bool? isMenuCommandInFlight,
    bool? isResolvingPenalty,
    int? rouletteRetry,
    bool? hasRevealedHand,
    int? handDealVersion,
    Object? errorMessage = _notProvided,
    Object? liarVerdictMessage = _notProvided,
    bool? liarVerdictIsFalse,
    bool? isLiarVerdictPending,
    Object? penaltyResult = _notProvided,
    bool? isPenaltyResultVisible,
    Object? interruption = _notProvided,
  }) {
    return LiarsPokerGameState(
      status: status ?? this.status,
      finishReason: identical(finishReason, _notProvided)
          ? this.finishReason
          : finishReason as String?,
      phase: phase ?? this.phase,
      table: table ?? this.table,
      turnUid: identical(turnUid, _notProvided)
          ? this.turnUid
          : turnUid as String?,
      winnerUid: identical(winnerUid, _notProvided)
          ? this.winnerUid
          : winnerUid as String?,
      penaltyTargetUid: identical(penaltyTargetUid, _notProvided)
          ? this.penaltyTargetUid
          : penaltyTargetUid as String?,
      lastPlayPlayerUid: identical(lastPlayPlayerUid, _notProvided)
          ? this.lastPlayPlayerUid
          : lastPlayPlayerUid as String?,
      lastPlayId: identical(lastPlayId, _notProvided)
          ? this.lastPlayId
          : lastPlayId as String?,
      lastPlayRevealed: lastPlayRevealed ?? this.lastPlayRevealed,
      lastPlayCardCount: lastPlayCardCount ?? this.lastPlayCardCount,
      round: round ?? this.round,
      revision: revision ?? this.revision,
      turnDeadlineAt: identical(turnDeadlineAt, _notProvided)
          ? this.turnDeadlineAt
          : turnDeadlineAt as int?,
      players: Map.unmodifiable(players ?? this.players),
      roundPlays: List.unmodifiable(roundPlays ?? this.roundPlays),
      handCards: List.unmodifiable(handCards ?? this.handCards),
      handCardAssets: List.unmodifiable(handCardAssets ?? this.handCardAssets),
      isCommandInFlight: isCommandInFlight ?? this.isCommandInFlight,
      isMenuCommandInFlight:
          isMenuCommandInFlight ?? this.isMenuCommandInFlight,
      isResolvingPenalty: isResolvingPenalty ?? this.isResolvingPenalty,
      rouletteRetry: rouletteRetry ?? this.rouletteRetry,
      hasRevealedHand: hasRevealedHand ?? this.hasRevealedHand,
      handDealVersion: handDealVersion ?? this.handDealVersion,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      liarVerdictMessage: identical(liarVerdictMessage, _notProvided)
          ? this.liarVerdictMessage
          : liarVerdictMessage as String?,
      liarVerdictIsFalse: liarVerdictIsFalse ?? this.liarVerdictIsFalse,
      isLiarVerdictPending: isLiarVerdictPending ?? this.isLiarVerdictPending,
      penaltyResult: identical(penaltyResult, _notProvided)
          ? this.penaltyResult
          : penaltyResult as PhonePenaltyResult?,
      isPenaltyResultVisible:
          isPenaltyResultVisible ?? this.isPenaltyResultVisible,
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
    );
  }
}
