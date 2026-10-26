// [round_reveal.dart] 는 태블릿 공개가 끝나기 전까지 휴대폰에 이전 하트·탈락 상태를 보여 주는 계산을 담은 파일이다.
//
// - [Package] : 파이널콜
// - [Model] : 라운드 결과 공개 전 표시용 플레이어 상태
//
// 서버는 판정 즉시 하트와 탈락을 반영하지만, 휴대폰이 이를 바로 보여 주면
// 태블릿에서 카드를 공개하기 전에 결과를 알게 되므로 필요한 파일이다.

import 'package:game_final_call/shared/models/game_models.dart';

/// 태블릿 공개 전에는 이번 라운드의 하트 손실과 탈락을 되돌린 플레이어를 돌려줍니다.
///
/// [revealPending]이 false이거나 이번 라운드에 바뀐 것이 없으면 [players]의
/// 값을 그대로 돌려줍니다. 한 팀원이 마지막 하트를 잃어 팀 전체가 탈락한
/// 경우에는 파트너도 공개 전까지 생존으로 보여 줍니다.
FinalCallPlayer? displayedFinalCallPlayer({
  required Map<String, FinalCallPlayer> players,
  required FinalCallRoundResult? roundResult,
  required bool revealPending,
  required String uid,
}) {
  final player = players[uid];
  if (player == null || !revealPending || roundResult == null) return player;
  final losses = roundResult.lifeLosses;
  final teamOutThisRound = players.values.any(
    (other) =>
        other.team == player.team &&
        other.lives == 0 &&
        (losses[other.uid] ?? 0) > 0,
  );
  final loss = losses[uid] ?? 0;
  if (loss == 0 && !teamOutThisRound) return player;
  return FinalCallPlayer(
    uid: player.uid,
    nickname: player.nickname,
    characterId: player.characterId,
    seatIndex: player.seatIndex,
    team: player.team,
    status: teamOutThisRound ? 'alive' : player.status,
    lives: player.lives + loss,
  );
}
