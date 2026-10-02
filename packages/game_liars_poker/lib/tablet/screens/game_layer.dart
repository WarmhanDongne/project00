// [game_layer.dart] 태블릿의 카드 분배·라운드 진행·결과 단계를
// 실제 화면 위젯으로 연결하는 tablet_board.dart의 내부 렌더링 파일이다.

part of '../tablet_board.dart';

class _RoundDealLayer extends StatefulWidget {
  const _RoundDealLayer({
    super.key,
    required this.roundNumber,
    required this.boardSeatCount,
    required this.playerSeatIndexes,
    required this.cardsPerPlayer,
    required this.flowStep,
    required this.onCompleted,
  });

  final int roundNumber;
  final int boardSeatCount;
  final List<int> playerSeatIndexes;
  final int cardsPerPlayer;
  final GameFlowStep<LiarsPokerTabletStage> flowStep;
  final VoidCallback onCompleted;

  @override
  State<_RoundDealLayer> createState() => _RoundDealLayerState();
}

class _RoundDealLayerState extends State<_RoundDealLayer> {
  // 안내 OFF는 이미 안내가 끝난 것과 같습니다. null 문구의 완료를 기다리면
  // 카드 분배가 시작되지 않아 서버 dealing에 계속 머물게 됩니다.
  bool get _showRoundIntro =>
      widget.roundNumber > 1 &&
      widget.flowStep.showAnnouncement &&
      !_introCompleted;
  bool _introCompleted = false;

  @override
  Widget build(BuildContext context) {
    if (widget.playerSeatIndexes.isEmpty) {
      // 공개 players와 좌석 배치가 아직 매칭되지 않으면 분배 애니메이션을
      // 만들 수 없습니다. 그렇다고 완료 신호 없이 대기만 하면 서버 phase가
      // dealing에 영구 고착되어 모든 기기가 멈추므로, 잠시 기다렸다가
      // 좌석 정보가 오지 않으면 완료 신호를 보내 게임을 진행시킵니다.
      // 그 사이 좌석 정보가 도착하면 아래 일반 분기로 전환됩니다.
      return GameFlowAutoComplete(
        key: ValueKey('deal-empty-${widget.roundNumber}'),
        delay: const Duration(seconds: 3),
        onCompleted: widget.onCompleted,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 룰렛이 퇴장하는 동안에도 중앙 카드팩은 이미 이 레이어에 있습니다.
        AbsorbPointer(
          absorbing: _showRoundIntro,
          child: !widget.flowStep.animation.enabled && !_showRoundIntro
              ? GameFlowAutoComplete(
                  key: ValueKey('deal-skipped-${widget.roundNumber}'),
                  delay:
                      widget.flowStep.beforeDelay + widget.flowStep.afterDelay,
                  onCompleted: widget.onCompleted,
                )
              : CardDealAnimation(
                  playerCount: widget.playerSeatIndexes.length,
                  boardSeatCount: widget.boardSeatCount,
                  playerSeatIndexes: widget.playerSeatIndexes,
                  cardsPerPlayer: widget.cardsPerPlayer,
                  cardAsset:
                      Assets.games.liarsPoker.images.cards.whiteBack.game,
                  duration: widget.flowStep.animation.duration,
                  beforeDelay: widget.flowStep.beforeDelay,
                  afterDelay: widget.flowStep.afterDelay,
                  // 첫 라운드만 중앙 덱을 직접 눌러 시작합니다. 2라운드부터는
                  // ROUND 안내가 끝나는 순간 자동 재생해 게임 흐름을 끊지 않습니다.
                  autoplay: widget.roundNumber > 1 && !_showRoundIntro,
                  tapToStart: widget.roundNumber == 1,
                  onCompleted: widget.onCompleted,
                ),
        ),
        Positioned.fill(
          child: GameAnnouncementLayer(
            announcement: _showRoundIntro
                ? widget.flowStep.buildAnnouncement()
                : null,
            style: const GameAnnouncementStyle.tablet(),
            onCompleted: (_) {
              if (!mounted) return;
              setState(() => _introCompleted = true);
            },
          ),
        ),
      ],
    );
  }
}
