part of '../game_screen.dart';

extension _LandscapeGameView on _LiarsPokerPhoneGameScreenState {
  Widget _buildLandscapeScreen(
    LiarsPokerController controller, {
    required PhoneGamePlayer? turnPlayer,
    required bool showHeader,
    required bool showControls,
    required bool showFoldPrompt,
    required bool showPenaltyHandOverlay,
    required bool hideHandDuringPenalty,
    required GameAnnouncement? announcement,
    required PhoneGameRegions regions,
  }) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final controlsWidth = (constraints.maxWidth * 0.29).clamp(
            200.0,
            250.0,
          );
          final safe = MediaQuery.paddingOf(context);
          final headerTop = 14.0 + safe.top;
          const headerHeight = 48.0;
          final bodyTop = headerTop + headerHeight + 6;
          final infoHeight = (constraints.maxHeight * .26).clamp(84.0, 104.0);
          final sidePadding = (constraints.maxWidth * 0.025).clamp(16.0, 28.0);
          final isPersistent =
              announcement?.kind == GameAnnouncementKind.persistent;

          return Stack(
            children: [
              // 가로 화면도 조건부 레이어의 순서 변화가 손패 State를 교체하지
              // 않도록 모든 Positioned를 역할별 key로 분리합니다.
              const Positioned.fill(
                key: ValueKey('landscape-background-slot'),
                child: _PhoneGameBackground(isLandscape: true),
              ),
              if (showHeader)
                Positioned(
                  key: const ValueKey('landscape-header-slot'),
                  top: headerTop,
                  left: sidePadding + safe.left,
                  right: sidePadding + safe.right,
                  child: _buildHeader(controller),
                ),
              if (showHeader &&
                  !showPenaltyHandOverlay &&
                  !widget.showSpectatorTopBar &&
                  !controller.isInitialLoading &&
                  controller.phase != 'dealing')
                Positioned(
                  key: const ValueKey('landscape-timer-slot'),
                  top: bodyTop,
                  right: sidePadding + safe.right,
                  width: controlsWidth,
                  height: infoHeight + 22,
                  child: _buildInfoRow(
                    controller,
                    turnPlayer: turnPlayer,
                    showTimer: regions.showTimer,
                    height: infoHeight,
                    compact: true,
                  ),
                ),
              // 방향 전환 전과 동일한 손패 State와 공개 완료값을 유지합니다.
              if (regions.showHand && !hideHandDuringPenalty)
                Positioned(
                  key: const ValueKey('landscape-hand-slot'),
                  top: bodyTop,
                  bottom: 8 + safe.bottom,
                  left: safe.left,
                  right: controlsWidth + sidePadding + safe.right + 8,
                  child: RepaintBoundary(
                    child: _buildHand(
                      controller,
                      isLandscape: true,
                      // 손패 영역은 오른쪽 조작부만큼 좁으므로, 최초 덱은
                      // 그 차이만큼 보정해야 실제 화면 정중앙에 표시됩니다.
                      entryCenterOffsetX: controlsWidth / 2 + 4,
                      entryCenterOffsetY: -32,
                      // 가로 손패 영역(top 72 / bottom 8)의 중앙은 화면 중앙보다
                      // 32 아래이므로, 덱과 같은 보정값이 문구에도 맞습니다.
                      announcementCenterOffset: Offset(
                        controlsWidth / 2 + 4,
                        -32,
                      ),
                      dimmed: showFoldPrompt || showPenaltyHandOverlay,
                    ),
                  ),
                ),
              // LIAR 판정 문구와 벌칙 결과는 같은 중앙 슬롯에서 전환합니다.
              if (showPenaltyHandOverlay)
                Positioned.fill(
                  key: const ValueKey('landscape-penalty-stage-slot'),
                  child: _PenaltyStageSwitcher(
                    verdictMessage: controller.liarVerdictMessage,
                    verdictPending: controller.isLiarVerdictPending,
                    player: controller.penaltyStatusPlayer,
                    result: controller.visiblePenaltyResult,
                    meUid: controller.uid,
                    lieRevealed:
                        controller.lastPlayDeclarationWasFalse == true &&
                        !controller.isLiarVerdictPending,
                    caller: controller.players[controller.liarCallerUid],
                  ),
                ),
              // 잔여카드 보유 생존자가 정확히 한 명일 때만 제출을 잠급니다.
              if (showFoldPrompt)
                Positioned(
                  key: const ValueKey('landscape-two-player-pass-slot'),
                  top: bodyTop,
                  bottom: 8 + safe.bottom,
                  left: sidePadding + safe.left,
                  right: controlsWidth + sidePadding + safe.right + 8,
                  child: _FoldPrompt(
                    enabled: controller.canFoldLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.foldLastCardChallenge()),
                  ),
                ),
              // 서버 권한 상태에 따라 LIAR/SUBMIT 조작을 활성화합니다.
              if (showControls)
                Positioned(
                  key: const ValueKey('landscape-turn-action-slot'),
                  right: sidePadding + safe.right,
                  top: bodyTop + infoHeight + 22,
                  bottom: 10 + safe.bottom,
                  width: controlsWidth,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TurnActionSwitcher(
                      isLandscape: true,
                      showLiarButton: controller.isMyTurn,
                      turnPlayer: turnPlayer,
                      liarButton: _buildGameActionButton(
                        controller,
                        isLandscape: true,
                      ),
                    ),
                  ),
                ),
              // 문구 레이어는 포인터를 가로채지 않으며 같은 슬롯을 유지합니다.
              Positioned.fill(
                key: const ValueKey('landscape-announcement-slot'),
                child: GameAnnouncementLayer(
                  announcement: announcement,
                  alignment: Alignment.center,
                  padding: isPersistent
                      ? EdgeInsets.fromLTRB(
                          sidePadding,
                          bodyTop,
                          controlsWidth + 24,
                          8,
                        )
                      : const EdgeInsets.symmetric(horizontal: 32),
                  offset: Offset.zero,
                  style: _announcementStyle(
                    announcement,
                    isLandscape: true,
                    statusFontSize: 15,
                    isMyTurn: controller.isMyTurn,
                  ),
                  onCompleted: (completed) {
                    if (completed.kind == GameAnnouncementKind.gameStart) {
                      _handleGameStartCompleted();
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
