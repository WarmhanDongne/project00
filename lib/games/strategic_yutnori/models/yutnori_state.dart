import 'piece_model.dart';
import 'player_model.dart';

enum GamePhase {
  setup,        // 대기실 (팀 및 윷 세팅)
  throwing,     // 윷 던지기 대기 중
  moving,       // 윷을 던진 후, 이동할 말 선택 및 이동 대기 중
  finished,     // 게임 종료 (승리팀 결정)
}

enum YutResult {
  backDo, // 뒷면 1개 (이 게임에서는 모든 '도'가 '백도'로 간주됨)
  gae,    // 뒷면 2개
  geol,   // 뒷면 3개
  yut,    // 앞면 4개 (뒷면 0개)
  mo,     // 뒷면 4개 (앞면 0개)
}

extension YutResultExtension on YutResult {
  int get steps {
    switch (this) {
      case YutResult.backDo: return -1;
      case YutResult.gae: return 2;
      case YutResult.geol: return 3;
      case YutResult.yut: return 4;
      case YutResult.mo: return 5;
    }
  }
}

class YutnoriState {
  final GamePhase phase;
  
  // 현재 턴인 팀 ID ('A' or 'B')
  final String currentTurnTeamId;
  
  // 이번 턴에 사용 가능한 윷 결과 목록 (윷, 모, 잡기로 인해 여러 개가 쌓일 수 있음)
  final List<YutResult> availableMoves;
  
  // 윷판 위에 있거나 대기실, 완주한 모든 말들의 상태
  final List<PieceModel> pieces;
  
  // 게임에 참가 중인 4명의 플레이어 정보
  final List<PlayerModel> players;
  
  // 승리한 팀 ID (게임이 끝나지 않았으면 null)
  final String? winnerTeamId;

  const YutnoriState({
    this.phase = GamePhase.setup,
    this.currentTurnTeamId = 'A',
    this.availableMoves = const [],
    this.pieces = const [],
    this.players = const [],
    this.winnerTeamId,
  });

  YutnoriState copyWith({
    GamePhase? phase,
    String? currentTurnTeamId,
    List<YutResult>? availableMoves,
    List<PieceModel>? pieces,
    List<PlayerModel>? players,
    String? winnerTeamId,
  }) {
    return YutnoriState(
      phase: phase ?? this.phase,
      currentTurnTeamId: currentTurnTeamId ?? this.currentTurnTeamId,
      availableMoves: availableMoves ?? this.availableMoves,
      pieces: pieces ?? this.pieces,
      players: players ?? this.players,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
    );
  }
}
