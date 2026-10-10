part of '../game_screen.dart';

extension _PortraitGameView on _LiarsPokerPhoneGameScreenState {
  Widget _buildPortraitScreen(
    LiarsPokerController? controller, {
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
          final layout = _PortraitGameLayout.fromSize(
            Size(constraints.maxWidth, constraints.maxHeight),
            topSafeArea: MediaQuery.paddingOf(context).top,
            bottomSafeArea: MediaQuery.paddingOf(context).bottom,
          );
          final isPersistent =
              announcement?.kind == GameAnnouncementKind.persistent;

          return Stack(
            children: [
              // 조건부 레이어가 추가·삭제되어도 손패 State가 다른 Positioned로
              // 재사용되지 않도록 모든 레이어에 역할별 고유 key를 유지합니다.
              const Positioned.fill(
                key: ValueKey('portrait-background-slot'),
                child: _PhoneGameBackground(),
              ),
              if (showHeader)
                Positioned(
                  key: const ValueKey('portrait-header-slot'),
                  top: layout.headerTop,
                  left: layout.horizontalPadding,
                  right: layout.horizontalPadding,
                  child: _buildHeader(
                    controller,
                    entryAnimation: controller?.recoverySession.canSend == false
                        ? null
                        : _controlsEntryController,
                  ),
                ),
              // 기준 카드와 남은 시간(다른 사람 차례에는 그 사람 얼굴)입니다.
              // 서버 deadline을 표시할 뿐 로컬에서 턴 결과를 판정하지 않습니다.
              if (showHeader &&
                  !showPenaltyHandOverlay &&
                  !widget.showSpectatorTopBar &&
                  controller != null &&
                  !controller.isInitialLoading &&
                  controller.phase != 'dealing')
                Positioned(
                  key: const ValueKey('portrait-timer-slot'),
                  top: layout.timerTop,
                  left: layout.horizontalPadding,
                  right: layout.horizontalPadding,
                  height: layout.tableHeight,
                  child: ControlEntryAnimation(
                    animation: _controlsEntryController,
                    style: ControlEntryStyle.header,
                    begin: 0,
                    end: 0.76,
                    child: _buildInfoRow(
                      controller,
                      turnPlayer: turnPlayer,
                      showTimer: regions.showTimer,
                      height: layout.tableHeight,
                    ),
                  ),
                ),
              // 서버 권한 상태에 따라 LIAR/SUBMIT 조작을 활성화합니다.
              if (showControls)
                Positioned(
                  key: const ValueKey('portrait-turn-action-slot'),
                  top: layout.actionTop,
                  left: layout.horizontalPadding,
                  right: 0,
                  child: TurnActionSwitcher(
                    isLandscape: false,
                    portraitControlHeight: layout.actionHeight,
                    showLiarButton: controller?.isMyTurn ?? true,
                    turnPlayer: turnPlayer,
                    liarButton: _buildGameActionButton(
                      controller,
                      isLandscape: false,
                      portraitHeight: layout.actionHeight,
                    ),
                  ),
                ),
              // dealing에서는 ROUND/Table 안내 뒤 손패 공개 연출을 실행합니다.
              if (regions.showHand && !hideHandDuringPenalty)
                Positioned(
                  key: const ValueKey('portrait-hand-slot'),
                  top: layout.handTop,
                  left: 0,
                  right: 0,
                  height: layout.handHeight,
                  child: RepaintBoundary(
                    child: _buildHand(
                      controller,
                      isLandscape: false,
                      // 손패 영역은 화면 정중앙보다 조금 위에 있으므로 그만큼
                      // 내려 ROUND·기준 카드 문구를 화면 가운데에 놓습니다.
                      announcementCenterOffset: Offset(
                        0,
                        layout.announcementCenterOffsetY,
                      ),
                      dimmed: showFoldPrompt || showPenaltyHandOverlay,
                    ),
                  ),
                ),
              // LIAR 판정 문구와 벌칙 결과는 같은 중앙 슬롯에서 전환합니다.
              if (showPenaltyHandOverlay && controller != null)
                Positioned.fill(
                  key: const ValueKey('portrait-penalty-stage-slot'),
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
              // 잔여카드 보유 생존자가 정확히 한 명일 때만 손패를 잠그고
              // LIAR/FOLD를 표시합니다. 단순한 "마지막 미제출자"가 아닙니다.
              if (showFoldPrompt && controller != null)
                Positioned(
                  key: const ValueKey('portrait-two-player-pass-slot'),
                  top: layout.handTop,
                  left: 0,
                  right: 0,
                  height: layout.handHeight,
                  child: _FoldPrompt(
                    enabled: controller.canFoldLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.foldLastCardChallenge()),
                  ),
                ),
              // 문구 레이어는 포인터를 가로채지 않으며 같은 슬롯을 유지합니다.
              Positioned.fill(
                key: const ValueKey('portrait-announcement-slot'),
                child: GameAnnouncementLayer(
                  announcement: announcement,
                  alignment: isPersistent
                      ? Alignment.topCenter
                      : Alignment.center,
                  padding: isPersistent
                      ? EdgeInsets.fromLTRB(
                          layout.messagePadding,
                          layout.statusTop,
                          layout.messagePadding,
                          0,
                        )
                      : const EdgeInsets.symmetric(horizontal: 32),
                  style: _announcementStyle(
                    announcement,
                    isLandscape: false,
                    statusFontSize: layout.statusFontSize,
                    isMyTurn: controller?.isMyTurn ?? false,
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
