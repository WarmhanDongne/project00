// [game_state.dart] 라이어스 포커의 현재 게임 전체 상태를 저장하고,
// 상태 변경 및 화면 갱신에 필요한 데이터를 관리하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_liars_poker/shared/models/game_models.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';

// ============================================================

// ---------------------------------------------------------------------------
// null 값 변경 구분
// ---------------------------------------------------------------------------

// copyWith()에서 "값을 전달하지 않음"과 "null로 변경"을 구분하기 위한 특수 값
const Object _notProvided = Object();

// ---------------------------------------------------------------------------
// 라이어스 포커 게임 전체 상태
// ---------------------------------------------------------------------------
@immutable
class LiarsPokerGameState implements GameSessionState<LiarsPokerGameState> {
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
    required this.commandInFlight,
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

  // ===[ 게임 초기 상태 생성 ]===
  // 게임 상태가 처음 만들어질 때 사용할 기본값을 설정한다.
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
    handCardAssets: <GameImage>[],
    commandInFlight: false,
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

  // ---------------------------------------------------------------------------
  // 게임 상태 데이터
  // ---------------------------------------------------------------------------

  // ===[ 게임 진행 상태 ]===
  final String status; // 게임 전체 상태
  final String? finishReason; // 게임 종료 이유
  final String phase; // 현재 게임 진행 단계
  final String table; // 현재 테이블의 기준 카드 값
  final int round; // 현재 라운드
  final int revision; // 서버 게임 상태 버전

  // ===[ 턴 및 승리 상태 ]===
  final String? turnUid; // 현재 차례인 플레이어
  final String? winnerUid; // 승리한 플레이어
  final int? turnDeadlineAt; // 현재 턴 제한 시간

  // ===[ 플레이어 상태 ]===
  // 현재 게임에 참가 중인 플레이어 전체
  final Map<String, PhoneGamePlayer> players;

  // ===[ 카드 제출 상태 ]===
  final String? lastPlayPlayerUid; // 마지막으로 카드를 제출한 플레이어
  final String? lastPlayId; // 마지막 카드 제출 기록 id
  final bool lastPlayRevealed; // 마지막 제출 카드 공개 여부
  final int lastPlayCardCount; // 마지막으로 제출한 카드 장수

  // 이번 라운드의 전체 카드 제출 기록
  final List<PublicLastPlay> roundPlays;

  // ===[ 플레이어 손패 상태 ]===
  // 현재 휴대폰 플레이어가 가지고 있는 카드
  final List<PhoneHandCard> handCards;

  // 손패를 화면에 표시할 때 사용하는 카드 이미지
  final List<GameImage> handCardAssets;

  // 손패가 공개되었는지 여부
  final bool hasRevealedHand;

  // 새로운 손패가 배분될 때 변경되는 버전 값
  final int handDealVersion;

  // ===[ 게임 명령 상태 ]===
  // 일반 게임 명령을 서버에서 처리 중인지 여부
  @override
  final bool commandInFlight;

  // 재시작/종료 등 설정 메뉴 명령을 처리 중인지 여부
  final bool isMenuCommandInFlight;

  // ===[ 룰렛 상태 ]===
  final String? penaltyTargetUid; // 룰렛 벌칙 대상 플레이어
  final bool isResolvingPenalty; // 룰렛 결과를 서버에 전달 중인지 여부
  final int rouletteRetry; // 룰렛 결과 전달 실패 횟수
  final PhonePenaltyResult? penaltyResult; // 룰렛 결과
  final bool isPenaltyResultVisible; // 룰렛 결과 화면 표시 여부

  // ===[ 라이어 판정 상태 ]===
  final String? liarVerdictMessage; // 라이어 판정 메시지
  final bool liarVerdictIsFalse; // 라이어 선언이 틀렸는지 여부
  final bool isLiarVerdictPending; // 라이어 판정 처리 중인지 여부

  // ===[ 오류 및 게임 중단 상태 ]===
  @override
  final String? errorMessage; // 오류 메시지

  // 게임 중단/이탈 등의 상태
  final GameInterruption? interruption;

  // ---------------------------------------------------------------------------
  // 게임 상태 변경
  // ---------------------------------------------------------------------------

  // ===[ 게임 상태 복사 및 변경 ]===
  // 기존 게임 상태를 유지하면서 전달된 값만 변경한 새로운 상태를 생성한다.
  //
  // nullable 필드는 _notProvided를 사용해
  // "변경하지 않음"과 "null로 변경"을 구분한다.
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
    List<GameImage>? handCardAssets,
    bool? commandInFlight,
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

      // List와 Map 내부 데이터도 외부에서 직접 변경하지 못하도록 보호한다.
      players: Map.unmodifiable(players ?? this.players),
      roundPlays: List.unmodifiable(roundPlays ?? this.roundPlays),
      handCards: List.unmodifiable(handCards ?? this.handCards),
      handCardAssets: List.unmodifiable(handCardAssets ?? this.handCardAssets),

      commandInFlight: commandInFlight ?? this.commandInFlight,

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

  // ---------------------------------------------------------------------------
  // 게임 상태 데이터 비교
  // ---------------------------------------------------------------------------

  // ===[ 게임 상태 데이터 비교 ]===
  // 이전 게임 상태와 새로운 게임 상태의 모든 주요 데이터를 비교한다.
  // 모든 값이 같으면 같은 상태, 하나라도 다르면 변경된 상태로 판단한다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LiarsPokerGameState &&
        status == other.status &&
        finishReason == other.finishReason &&
        phase == other.phase &&
        table == other.table &&
        turnUid == other.turnUid &&
        winnerUid == other.winnerUid &&
        penaltyTargetUid == other.penaltyTargetUid &&
        lastPlayPlayerUid == other.lastPlayPlayerUid &&
        lastPlayId == other.lastPlayId &&
        lastPlayRevealed == other.lastPlayRevealed &&
        lastPlayCardCount == other.lastPlayCardCount &&
        round == other.round &&
        revision == other.revision &&
        turnDeadlineAt == other.turnDeadlineAt &&
        // Map 내부의 플레이어 데이터까지 비교한다.
        mapEquals(players, other.players) &&
        // List 내부의 데이터까지 순서대로 비교한다.
        listEquals(roundPlays, other.roundPlays) &&
        listEquals(handCards, other.handCards) &&
        listEquals(handCardAssets, other.handCardAssets) &&
        commandInFlight == other.commandInFlight &&
        isMenuCommandInFlight == other.isMenuCommandInFlight &&
        isResolvingPenalty == other.isResolvingPenalty &&
        rouletteRetry == other.rouletteRetry &&
        hasRevealedHand == other.hasRevealedHand &&
        handDealVersion == other.handDealVersion &&
        errorMessage == other.errorMessage &&
        liarVerdictMessage == other.liarVerdictMessage &&
        liarVerdictIsFalse == other.liarVerdictIsFalse &&
        isLiarVerdictPending == other.isLiarVerdictPending &&
        penaltyResult == other.penaltyResult &&
        isPenaltyResultVisible == other.isPenaltyResultVisible &&
        interruption == other.interruption;
  }

  // ===[ 게임 상태 hashCode 생성 ]===
  // == 비교 기준과 동일한 데이터로 hashCode를 생성한다.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    status,
    finishReason,
    phase,
    table,
    turnUid,
    winnerUid,
    penaltyTargetUid,
    lastPlayPlayerUid,
    lastPlayId,
    lastPlayRevealed,
    lastPlayCardCount,
    round,
    revision,
    turnDeadlineAt,

    // Map은 순서와 관계없이 플레이어 데이터를 기준으로 hash를 생성한다.
    Object.hashAllUnordered(
      players.entries.map((e) => Object.hash(e.key, e.value)),
    ),

    Object.hashAll(roundPlays),
    Object.hashAll(handCards),
    Object.hashAll(handCardAssets),

    commandInFlight,
    isMenuCommandInFlight,
    isResolvingPenalty,
    rouletteRetry,
    hasRevealedHand,
    handDealVersion,
    errorMessage,
    liarVerdictMessage,
    liarVerdictIsFalse,
    isLiarVerdictPending,
    penaltyResult,
    isPenaltyResultVisible,
    interruption,
  ]);

  // ---------------------------------------------------------------------------
  // 공용 게임 컨트롤러 연결
  // ---------------------------------------------------------------------------

  // GameSessionController가 라이어스 포커 내부 구조를 몰라도
  // 공통적인 게임 명령 시작/종료/오류/게임 종료 상태를 변경할 수 있게 한다.

  // ===[ 게임 명령 시작 ]===
  // 서버 명령을 처리 중인 상태로 변경하고 기존 오류를 초기화한다.
  @override
  LiarsPokerGameState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);

  // ===[ 게임 명령 종료 ]===
  // 서버 명령 처리가 끝났음을 표시한다.
  @override
  LiarsPokerGameState markCommandFinished() => copyWith(commandInFlight: false);

  // ===[ 오류 상태 변경 ]===
  // 전달받은 오류 메시지를 현재 게임 상태에 저장한다.
  @override
  LiarsPokerGameState withError(String? message) =>
      copyWith(errorMessage: message);

  // ===[ 게임 종료 상태 변경 ]===
  // 게임이 제거되거나 수동 종료되었을 때 종료 상태로 변경한다.
  @override
  LiarsPokerGameState asRemovedGame() => copyWith(
    status: 'finished',
    finishReason: 'manual',
    phase: 'finished',
    turnUid: null,
    turnDeadlineAt: null,
  );
}
