import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/player_layouts/player_layout_editor.dart';
import 'package:game_kit/player_layouts/player_layout_factory.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/player_layouts/seating_roster_guard.dart';
import 'package:game_kit/widgets/game_route_exit.dart';
import 'package:game_kit/widgets/game_exit_route.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';
import 'package:project00/platform/home/tablet/book_open_route.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_compatibility.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_restore_to_waiting.dart';
import 'package:project00/platform/home/tablet/tablet_game_start.dart';

/// 로비를 유지한 채 자리 배치에서 게임으로 이어지는 기존 시작 흐름입니다.
Future<void> launchTabletGame({
  required BuildContext context,
  required GameInfo game,
  required RoomProvider provider,
  required Future<bool> Function() ensureSelection,
  required bool Function() isCurrent,
  required VoidCallback onLaunched,
  Rect? Function()? originRect,
}) => _TabletGameLauncher(
  context,
  game,
  provider,
  ensureSelection,
  isCurrent,
  onLaunched,
  originRect,
).start();

class _TabletGameLauncher {
  _TabletGameLauncher(
    this.context,
    this.game,
    this.provider,
    this.ensureSelection,
    this.isCurrent,
    this.onLaunched,
    this.originRect,
  );
  final BuildContext context;
  final GameInfo game;
  final RoomProvider provider;
  final Future<bool> Function() ensureSelection;
  final bool Function() isCurrent;
  final VoidCallback onLaunched;

  /// 화면에서 고른 책의 자리입니다. 있으면 그 책이 열리며 자리 배치로 넘어갑니다.
  final Rect? Function()? originRect;

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> start() async {
    final initialRoom = provider.roomCode;
    if (initialRoom == null) return;
    final players = provider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final currentPlayerCount = players.length;
    final minPlayers = game.minPlayers > 0 ? game.minPlayers : 2;
    final maxPlayers = game.maxPlayers > 0
        ? game.maxPlayers
        : RoomLimits.defaultMaxPlayers;

    if (game.id.isEmpty) {
      _showMessage(context, '게임 정보를 확인할 수 없습니다.');
      return;
    }

    // 스토어 배포 후 서버에 추가된 게임은 이 빌드에 코드가 없을 수 있습니다.
    // 시작 지점 한 곳에서 막고 업데이트를 안내합니다.
    final templateGame = provider.gameCatalog.find(game.id);
    if (templateGame == null) {
      _showMessage(context, gameRequiresUpdateMessage);
      return;
    }
    final supportedCounts = templateGame.supportedPlayerCounts;
    if (supportedCounts != null &&
        !supportedCounts.contains(currentPlayerCount)) {
      _showMessage(
        context,
        '이 게임은 ${supportedCounts.join(' 또는 ')}명이 모이면 시작할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    if (supportedCounts == null && currentPlayerCount < minPlayers) {
      _showMessage(
        context,
        '이 게임은 최소 $minPlayers명부터 시작할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    if (supportedCounts == null && currentPlayerCount > maxPlayers) {
      _showMessage(
        context,
        '이 게임은 최대 $maxPlayers명까지 함께할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    try {
      await prepareGameAssetsForPlay(templateGame);
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '게임 에셋 준비');
      if (!context.mounted || !isCurrent()) return;
      _showMessage(context, '게임 파일을 다운로드하지 못했습니다. 네트워크를 확인해 주세요.');
      return;
    }
    if (!context.mounted || !isCurrent()) return;
    if (!isGamePlayableOnThisBuild(game, catalog: provider.gameCatalog)) {
      _showMessage(context, gameRequiresUpdateMessage);
      return;
    }

    final roomCode = provider.roomCode;
    if (roomCode == null || roomCode != initialRoom) {
      _showMessage(context, '방 정보를 확인할 수 없습니다.');
      return;
    }

    // 서버는 선택된 게임이 없으면 자리 배치를 거부합니다. 사용자가 응답보다
    // 빨리 눌렀다면 여기서만 잠깐 기다립니다.
    if (!await ensureSelection()) {
      if (!context.mounted || !isCurrent()) return;
      _showMessage(context, provider.errorMessage ?? '게임을 선택하지 못했습니다.');
      return;
    }
    if (!context.mounted || !isCurrent()) return;
    if (provider.roomCode != initialRoom) return;
    final seatingStarted = await provider.beginPlayerSeating();
    if (!context.mounted || !isCurrent()) return;
    if (!seatingStarted) {
      _showMessage(context, provider.errorMessage ?? '자리 배치를 시작하지 못했습니다.');
      return;
    }
    final lockedPlayers = provider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final initialLayout = PlayerLayoutFactory.create(lockedPlayers);

    //================상태바 표시=================
    // 게임 선택 직후 자리 배치 화면부터 실제 게임과 같은 전체 화면을 유지합니다.
    final origin = originRect?.call();
    unawaited(AppSystemUi.enterGameFullscreen());
    onLaunched();
    Widget buildSetup(BuildContext layoutContext) => _buildStartSetup(
      layoutContext,
      templateGame: templateGame,
      initialLayout: initialLayout,
      roomCode: roomCode,
    );
    Navigator.of(context).push<void>(
      origin == null
          ? MaterialPageRoute(builder: buildSetup)
          : BookOpenRoute(
              origin: origin,
              coverColor: MosiGameArt.of(
                game.id,
                fallbackName: game.name,
              ).spineColor,
              builder: buildSetup,
            ),
    );
  }

  /// 자리 배치 화면 자리에 무엇을 띄울지 정합니다.
  ///
  /// 게임이 자기만의 준비 화면을 주면([TemplateGame.buildStartSetupScreen])
  /// 그것을 띄우고, 없으면 공용 자리 배치를 띄웁니다. 게임 id로 분기하지
  /// 않으므로 게임을 추가할 때 이 파일은 손대지 않습니다.
  Widget _buildStartSetup(
    BuildContext layoutContext, {
    required TemplateGame templateGame,
    required PlayerLayoutModel initialLayout,
    required String roomCode,
  }) {
    // 게임 시작 명령이 서버에 닿은 뒤에는 참가자 변경으로 자리 배치를 되감지
    // 않습니다. 그 시점에는 이미 `game/public/status = playing`이라 선택 해제가
    // 서버에서 거부되고, 화면은 곧 게임 화면으로 교체됩니다.
    var startedGame = false;

    Future<bool> cancel() async {
      if (await hasPendingTabletGameStart(roomCode)) {
        if (layoutContext.mounted) {
          _showMessage(
            layoutContext,
            '게임 시작 요청의 결과를 먼저 확인해주세요. 설정 완료로 다시 확인할 수 있습니다.',
          );
        }
        return false;
      }
      final cleared = await provider.clearSelectedGame();
      if (!layoutContext.mounted) return false;
      if (!cleared) {
        _showMessage(
          layoutContext,
          provider.errorMessage ?? '게임 선택을 해제하지 못했습니다.',
        );
      }
      return cleared;
    }

    Future<bool> prepare(
      PlayerLayoutModel completedLayout, {
      Map<String, Object?>? options,
    }) async {
      try {
        final prepared = await prepareTabletGameStart(
          roomCode: roomCode,
          saveSeats: () => provider.savePlayerSeatIndexes({
            for (final player in completedLayout.players)
              player.uid: player.seatIndex,
          }),
          startGame: () => templateGame.startGame(roomCode, options: options),
          isCurrent: () =>
              layoutContext.mounted && provider.roomCode == roomCode,
        );
        if (!prepared) {
          if (layoutContext.mounted && provider.roomCode == roomCode) {
            _showMessage(
              layoutContext,
              provider.errorMessage ?? '플레이어 자리를 저장하지 못했습니다.',
            );
          }
          return false;
        }
        startedGame = true;
      } catch (error) {
        if (!layoutContext.mounted) return false;
        _showMessage(layoutContext, '게임을 시작하지 못했습니다.\n$error');
        return false;
      }
      return layoutContext.mounted;
    }

    /// 자리 배치 중 참가자 구성이 바뀌면 준비를 취소하고 대기실로 돌아갑니다.
    ///
    /// 낡은 자리 배치를 그대로 두면 서버가 좌석 저장을 거부하고
    /// (`saveRealtimePlayerSeatIndexes`의 UID 집합 일치 검사) 진행자에게는
    /// 원인을 알 수 없는 문구만 보입니다.
    Future<void> handleRosterChanged() async {
      if (startedGame || !layoutContext.mounted) return;
      if (await hasPendingTabletGameStart(roomCode)) return;
      if (!layoutContext.mounted || startedGame) return;
      // 화면을 닫기 전에 미리 잡아 둡니다. pop 뒤에는 이 context로 messenger를
      // 찾을 수 없어 안내가 사라진 화면과 함께 묻힙니다.
      final messenger = ScaffoldMessenger.of(layoutContext);
      // 서버 상태를 먼저 waiting으로 되돌립니다. 실패해도 화면은 닫습니다.
      // 낡은 배치를 들고 남아 있는 편이 더 나쁘고, 대기실에서 다시 고르면
      // 같은 선택 해제가 재시도됩니다.
      await provider.clearSelectedGame();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(GameFlowCopy.seatingRosterChanged)),
        );
      if (!layoutContext.mounted) return;
      // maybePop은 위에 쌓인 다이얼로그만 닫아 자리 배치 화면에 갇힙니다.
      exitGameRoute(layoutContext);
    }

    void complete(PlayerLayoutModel completedLayout) async {
      final cleanupTarget = await provider.captureGameTarget();
      if (!layoutContext.mounted) return;
      //=======================태블릿 게임 방향 불변 조건==============================
      // 모든 태블릿 게임은 게임별 휴대폰 정책과 관계없이 항상 가로입니다.
      unawaited(AppOrientation.lockTabletGameLandscape());
      // 자리 배치 연출이 화면을 게임 배경색으로 가득 채운 채로 끝나므로,
      // 여기서 슬라이드·페이드 같은 전환 효과를 주면 오히려 화면이
      // 바뀌었다는 느낌이 들어 연출이 끊겨 보입니다. 전환 없이 즉시
      // 바꿔서 하나의 연출처럼 이어지게 합니다.
      final gameRoute = GameExitInstantPageRoute<void>(
        pageBuilder: (_, _, _) => templateGame.buildTabletScreen(
          playerLayout: completedLayout,
          provider: provider,
          roomCode: roomCode,
        ),
      );
      Navigator.of(layoutContext).pushReplacement(gameRoute);
      // 게임 화면의 퇴장 연출까지 끝난 뒤에 게임 데이터를 정리합니다.
      // 먼저 지우면 덮이는 동안 결과 화면이 사라질 수 있습니다.
      gameRoute.completed.then(
        (_) => unawaited(
          restoreRoomToWaiting(
            provider,
            expectedTarget: cleanupTarget,
            captured: true,
          ),
        ),
      );
    }

    // 공용 자리 배치와 게임별 준비 화면을 **여기서 한 번** 감쌉니다. 두 화면을
    // 각각 고치면 게임을 추가할 때마다 같은 코드를 또 씁니다.
    return SeatingRosterGuard(
      provider: provider,
      onRosterChanged: () => unawaited(handleRosterChanged()),
      child:
          templateGame.buildStartSetupScreen(
            layout: initialLayout,
            onPrepare: prepare,
            onComplete: complete,
            onCancel: cancel,
          ) ??
          PlayerLayoutEditor(
            initialLayout: initialLayout,
            tableColor: templateGame.tableColor,
            tableBackgroundImage: templateGame.tableBackgroundImage,
            tableImage: templateGame.layoutTableImage,
            chairImage: templateGame.layoutChairImage,
            seatTheme: MosiSeatTheme.of(templateGame.id),
            onCancel: cancel,
            onPrepare: prepare,
            onComplete: complete,
          ),
    );
  }
}
