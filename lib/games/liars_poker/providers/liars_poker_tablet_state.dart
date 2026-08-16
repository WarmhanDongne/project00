import 'package:flutter/foundation.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

const Object _notProvided = Object();

//=======================Liar's Poker 태블릿 불변 상태==============================
@immutable
class LiarsPokerTabletState {
  const LiarsPokerTabletState({
    required this.stage,
    required this.table,
    required this.serverPhase,
    required this.roundNumber,
    required this.cardPileVersion,
    required this.penaltyAttemptCount,
    required this.rouletteRetry,
    required this.isResolvingPenalty,
    required this.isProcessingMenuCommand,
    required this.isInsufficientPlayersEnding,
    required this.endingMessage,
    required this.turnUid,
    required this.winnerUid,
    required this.winnerPlayer,
    required this.penaltyTargetUid,
    required this.penaltyPlayer,
    required this.roundPlays,
    required this.activeAnimationPlayId,
    required this.profileImageUrls,
    required this.remainingCardCounts,
    required this.interruption,
  });

  factory LiarsPokerTabletState.initial(int playerCount) =>
      LiarsPokerTabletState(
        stage: LiarsPokerTabletStage.waiting,
        table: 'K',
        serverPhase: 'playing',
        roundNumber: 1,
        cardPileVersion: 0,
        penaltyAttemptCount: 0,
        rouletteRetry: 0,
        isResolvingPenalty: false,
        isProcessingMenuCommand: false,
        isInsufficientPlayersEnding: false,
        endingMessage: null,
        turnUid: null,
        winnerUid: null,
        winnerPlayer: null,
        penaltyTargetUid: null,
        penaltyPlayer: null,
        roundPlays: const <SubmittedPlay>[],
        activeAnimationPlayId: null,
        profileImageUrls: const <String>[],
        remainingCardCounts: List<int>.filled(playerCount, cardsPerPlayer),
        interruption: null,
      );

  final LiarsPokerTabletStage stage;
  final String table;
  final String serverPhase;
  final int roundNumber;
  final int cardPileVersion;
  final int penaltyAttemptCount;
  final int rouletteRetry;
  final bool isResolvingPenalty;
  final bool isProcessingMenuCommand;
  final bool isInsufficientPlayersEnding;
  final String? endingMessage;
  final String? turnUid;
  final String? winnerUid;
  final PlayerLayoutPlayer? winnerPlayer;
  final String? penaltyTargetUid;
  final PlayerLayoutPlayer? penaltyPlayer;
  final List<SubmittedPlay> roundPlays;
  final String? activeAnimationPlayId;
  final List<String> profileImageUrls;
  final List<int> remainingCardCounts;
  final GameInterruption? interruption;

  LiarsPokerTabletState copyWith({
    LiarsPokerTabletStage? stage,
    String? table,
    String? serverPhase,
    int? roundNumber,
    int? cardPileVersion,
    int? penaltyAttemptCount,
    int? rouletteRetry,
    bool? isResolvingPenalty,
    bool? isProcessingMenuCommand,
    bool? isInsufficientPlayersEnding,
    Object? endingMessage = _notProvided,
    Object? turnUid = _notProvided,
    Object? winnerUid = _notProvided,
    Object? winnerPlayer = _notProvided,
    Object? penaltyTargetUid = _notProvided,
    Object? penaltyPlayer = _notProvided,
    List<SubmittedPlay>? roundPlays,
    Object? activeAnimationPlayId = _notProvided,
    List<String>? profileImageUrls,
    List<int>? remainingCardCounts,
    Object? interruption = _notProvided,
  }) {
    return LiarsPokerTabletState(
      stage: stage ?? this.stage,
      table: table ?? this.table,
      serverPhase: serverPhase ?? this.serverPhase,
      roundNumber: roundNumber ?? this.roundNumber,
      cardPileVersion: cardPileVersion ?? this.cardPileVersion,
      penaltyAttemptCount: penaltyAttemptCount ?? this.penaltyAttemptCount,
      rouletteRetry: rouletteRetry ?? this.rouletteRetry,
      isResolvingPenalty: isResolvingPenalty ?? this.isResolvingPenalty,
      isProcessingMenuCommand:
          isProcessingMenuCommand ?? this.isProcessingMenuCommand,
      isInsufficientPlayersEnding:
          isInsufficientPlayersEnding ?? this.isInsufficientPlayersEnding,
      endingMessage: identical(endingMessage, _notProvided)
          ? this.endingMessage
          : endingMessage as String?,
      turnUid: identical(turnUid, _notProvided)
          ? this.turnUid
          : turnUid as String?,
      winnerUid: identical(winnerUid, _notProvided)
          ? this.winnerUid
          : winnerUid as String?,
      winnerPlayer: identical(winnerPlayer, _notProvided)
          ? this.winnerPlayer
          : winnerPlayer as PlayerLayoutPlayer?,
      penaltyTargetUid: identical(penaltyTargetUid, _notProvided)
          ? this.penaltyTargetUid
          : penaltyTargetUid as String?,
      penaltyPlayer: identical(penaltyPlayer, _notProvided)
          ? this.penaltyPlayer
          : penaltyPlayer as PlayerLayoutPlayer?,
      roundPlays: List.unmodifiable(roundPlays ?? this.roundPlays),
      activeAnimationPlayId: identical(activeAnimationPlayId, _notProvided)
          ? this.activeAnimationPlayId
          : activeAnimationPlayId as String?,
      profileImageUrls: List.unmodifiable(
        profileImageUrls ?? this.profileImageUrls,
      ),
      remainingCardCounts: List.unmodifiable(
        remainingCardCounts ?? this.remainingCardCounts,
      ),
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
    );
  }
}
