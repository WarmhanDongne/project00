import 'package:project00/platform/localization/lobby_connection_band.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:project00/platform/localization/locale_settings_button.dart';
import 'dart:async';
import 'package:project00/platform/home/store/store_motion.dart';

import 'package:flutter/material.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/widgets/game_exit_route.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/player_layouts/player_layout_factory.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_restore_to_waiting.dart';
import 'package:project00/platform/home/store/screens/tablet_store_screen.dart';
import 'package:project00/platform/home/tablet/screens/tablet_game_detail.dart';
import 'package:project00/platform/sound/lobby_music.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_layout.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_content_transition.dart';
import 'package:project00/platform/home/tablet/tablet_lobby_selection.dart';
import 'package:project00/platform/home/tablet/tablet_game_launcher.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';

//=======================태블릿 플랫폼 홈==============================
class TabletHome extends StatefulWidget {
  const TabletHome({super.key, required this.gameCatalog});

  final GameCatalog gameCatalog;

  @override
  State<TabletHome> createState() => _TabletHomeState();
}

class _TabletHomeState extends State<TabletHome>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _storeExit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool _isOpeningStore = false;

  /// 아래 연결 띠가 듣는 서버 연결 상태입니다. 다시 그려도 같은 스트림을 씁니다.
  late final Stream<bool> _serverConnection = roomProvider
      .watchServerConnection();

  /// 선반에서 고른 책 자리를 잽니다. 게임을 시작하면 이 책이 열립니다.
  final GlobalKey _selectedCoverKey = GlobalKey();

  late final RoomProvider roomProvider = RoomProvider(
    gameCatalog: widget.gameCatalog,
  );
  final GameProvider gameProvider = GameProvider();
  String? _selectedGameId;
  bool _isDetailOpen = false;
  bool _isStarting = false;
  late final TabletLobbySelection _selection = TabletLobbySelection(
    roomProvider,
  );
  bool _onlyPlayable = false;
  StreamSubscription<String?>? _restoredGameStatusSubscription;
  String? _restoredStatusRoomCode;
  String? _restoredGameStatus;
  Future<bool>? _restoredFinishedCleanup;
  bool _isOpeningRestoredGame = false;

  @override
  void initState() {
    super.initState();
    //================상태바 표시=================
    unawaited(AppSystemUi.showPlatformSystemBars());
    //=======================초기 화면 방향 요청 금지==============================
    // 앱 첫 실행에서는 이 initState가 iOS scene 연결보다 먼저 호출될 수 있습니다.
    // 초기 태블릿 가로 고정은 main.dart가 lifecycle resumed 이후 한 번만 적용합니다.
    // 게임 종료 후 복원은 각 태블릿 게임 화면의 dispose가 담당합니다.
    //=======================controller 방 복구==============================
    // dispose나 lifecycle은 방 삭제 신호가 아닙니다. 저장된 session으로 기존
    // 방을 복구하고, background에서는 heartbeat만 멈춥니다.
    WidgetsBinding.instance.addObserver(this);
    roomProvider.addListener(_syncRestoredGame);
    _selection.addListener(_onSelectionChanged);
    unawaited(roomProvider.restoreControllerRoom());
  }

  void _syncRestoredGame() {
    final code = roomProvider.roomCode;
    if (code == null) {
      _restoredStatusRoomCode = null;
      _restoredGameStatus = null;
      unawaited(_restoredGameStatusSubscription?.cancel());
      _restoredGameStatusSubscription = null;
      return;
    }
    if (_restoredStatusRoomCode == code) {
      _restoreFinishedRoomIfReady(code);
      return;
    }
    _restoredStatusRoomCode = code;
    _restoredGameStatus = null;
    unawaited(_restoredGameStatusSubscription?.cancel());
    _restoredGameStatusSubscription = roomProvider.watchGameStatus(code).listen(
      (status) {
        if (roomProvider.roomCode != code || _restoredStatusRoomCode != code) {
          return;
        }
        _restoredGameStatus = status;
        if (status == 'playing') unawaited(_openRestoredGameIfReady(code));
        if (status == 'finished') _restoreFinishedRoomIfReady(code);
      },
      onError: (_) {},
    );
  }

  void _restoreFinishedRoomIfReady(String roomCode) {
    if (_restoredFinishedCleanup != null ||
        roomProvider.roomCode != roomCode ||
        _restoredGameStatus != 'finished' ||
        !roomProvider.isRoomFinished ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _isOpeningRestoredGame ||
        _isOpeningStore ||
        _isStarting ||
        _isDetailOpen) {
      return;
    }
    final cleanup = restoreFinishedRoomOnControllerHome(
      provider: roomProvider,
      gameStatus: _restoredGameStatus,
      isControllerHomeCurrent:
          mounted && ModalRoute.of(context)?.isCurrent == true,
      isOpeningGame: _isOpeningRestoredGame,
    );
    _restoredFinishedCleanup = cleanup;
    unawaited(
      cleanup.whenComplete(() {
        if (identical(_restoredFinishedCleanup, cleanup)) {
          _restoredFinishedCleanup = null;
        }
      }),
    );
  }

  Future<void> _openRestoredGameIfReady(String roomCode) async {
    if (_isOpeningRestoredGame ||
        _isOpeningStore ||
        _isStarting ||
        _isDetailOpen ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final gameId = roomProvider.selectedGameId;
    final game = gameId == null ? null : widget.gameCatalog.find(gameId);
    // 이 빌드가 모르는 게임(스토어 배포 후 추가된 게임)이면 재시도해도
    // 영원히 열 수 없습니다. 무한 재시도 대신 복원을 포기하고 안내합니다.
    if (gameId != null && game == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('진행 중인 게임을 열려면 앱을 업데이트해 주세요.')),
        );
      return;
    }
    if (game == null || roomProvider.players.isEmpty) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 150),
          () => _openRestoredGameIfReady(roomCode),
        ),
      );
      return;
    }

    _isOpeningRestoredGame = true;
    try {
      if (!await prepareGameAssetsForRecovery(game, context)) {
        _isOpeningRestoredGame = false;
        await roomProvider.closeControllerRoom();
        return;
      }
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '태블릿 복구 게임 에셋 확인');
      _isOpeningRestoredGame = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('게임 파일을 다운로드하지 못했습니다.')));
      return;
    }
    if (!mounted || roomProvider.roomCode != roomCode) {
      _isOpeningRestoredGame = false;
      return;
    }

    final players = [...roomProvider.players]
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final savedSeats = players.map((player) => player.seatIndex).toSet();
    final hasValidSavedSeats =
        savedSeats.length == players.length &&
        savedSeats.every((seat) => seat >= 0 && seat < players.length);
    final layout = hasValidSavedSeats
        ? PlayerLayoutModel(
            players: List.unmodifiable(
              players.map(
                (player) => PlayerLayoutPlayer(
                  uid: player.uid,
                  nickname: player.nickname,
                  characterId: player.characterId,
                  seatIndex: player.seatIndex,
                ),
              ),
            ),
          )
        : PlayerLayoutFactory.create(players);

    //================상태바 표시=================
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.lockTabletGameLandscape());
    final cleanupTarget = await roomProvider.captureGameTarget();
    if (!mounted) return;
    final gameRoute = GameExitMaterialPageRoute<void>(
      builder: (_) => game.buildTabletScreen(
        playerLayout: layout,
        provider: roomProvider,
        roomCode: roomCode,
      ),
    );
    Navigator.of(context).push(gameRoute);
    gameRoute.completed.then((_) {
      _isOpeningRestoredGame = false;
      // 복구 경로로 연 게임도 닫힐 때 방을 대기 상태로 되돌립니다(P-02).
      unawaited(
        restoreRoomToWaiting(
          roomProvider,
          expectedTarget: cleanupTarget,
          captured: true,
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(roomProvider.resumeControllerPresence());
      return;
    }
    //=======================일시적인 inactive는 끊김이 아닙니다==============================
    // iOS는 제어 센터를 내리거나 앱 스위처를 띄우기만 해도 inactive를 보냅니다.
    // 그때마다 controllerPresence.connected를 false로 내리면, 휴대폰들이 그 값을
    // '태블릿이 방을 닫았다'로 읽고 전원 방에서 나가 버립니다. 실제로 앱이
    // 내려간 paused/detached에서만 연결 해제로 처리합니다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(roomProvider.pauseControllerPresence());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    roomProvider.removeListener(_syncRestoredGame);
    unawaited(_restoredGameStatusSubscription?.cancel());
    // 화면 dispose는 명시적 방 종료가 아닙니다. heartbeat만 정리하고 방과
    // controller session은 재접속 유예시간 동안 서버에 유지합니다.
    unawaited(roomProvider.pauseControllerPresence());
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    roomProvider.dispose();
    gameProvider.dispose();
    _storeExit.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _openDetail(GameInfo game) {
    if (_isStarting || _isOpeningStore) return;
    setState(() {
      _selectedGameId = game.id;
      _isDetailOpen = true;
    });
    _selection.show(game);
  }

  Future<void> _closeDetail() async {
    if (_isStarting || _isOpeningStore) return;
    setState(() => _isDetailOpen = false);
    final cleared = await _selection.close();
    if (!mounted || cleared) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(roomProvider.errorMessage ?? '게임 선택을 해제하지 못했습니다.'),
      ),
    );
  }

  GameInfo? get _currentGame {
    if (_isDetailOpen) return _selection.game;
    final games = roomProvider.roomCode != null
        ? roomProvider.groupGames
        : gameProvider.games;
    for (final game in games) {
      if (game.id == _selectedGameId) return game;
    }
    return games.firstOrNull;
  }

  Future<void> _startSelectedGame() async {
    if (_isStarting || _isOpeningStore) return;
    final game = _currentGame;
    if (game == null || roomProvider.roomCode == null) return;
    setState(() => _isStarting = true);
    _selection.show(game);
    try {
      await launchTabletGame(
        context: context,
        game: game,
        provider: roomProvider,
        ensureSelection: _selection.prepare,
        isCurrent: () => mounted && _selection.game?.id == game.id,
        onLaunched: () {
          _isDetailOpen = false;
          _selection.didLaunch();
        },
        // 선반에서 시작했다면 그 책이 열리며 자리 배치로 넘어갑니다.
        originRect: () {
          final coverContext = _selectedCoverKey.currentContext;
          return coverContext == null ? null : mosiOriginOf(coverContext);
        },
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  int _maxSlots(GameInfo game) {
    final counts = roomProvider.gameCatalog
        .find(game.id)
        ?.supportedPlayerCounts;
    if (counts != null && counts.isNotEmpty) {
      return counts.reduce((a, b) => a > b ? a : b);
    }
    return game.maxPlayers > 0 ? game.maxPlayers : RoomLimits.defaultMaxPlayers;
  }

  Future<void> _openStore() async {
    if (_isOpeningStore || _isStarting) return;
    _isOpeningStore = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) await _storeExit.forward();
    if (!mounted) return;
    final selected = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 480),
        reverseTransitionDuration: Duration(
          milliseconds: reduceMotion ? 0 : 180,
        ),
        pageBuilder: (_, _, _) => LobbyMusic(
          track: LobbyTracks.store,
          child: TabletStoreScreen(gameProvider: gameProvider),
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _selectedGameId = selected;
        _onlyPlayable = false;
      });
    }
    if (!reduceMotion) await _storeExit.reverse();
    _isOpeningStore = false;
  }

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(_selectedGameId ?? 'liars_poker');
    final theme = art.shelfTheme;
    final detail = _isDetailOpen ? _selection.game : null;
    return LobbyMusic(
      track: LobbyTracks.lobby,
      child: PopScope(
        canPop: !_isDetailOpen && !_isStarting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isDetailOpen) unawaited(_closeDetail());
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: theme.ground),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, ground, child) => ListenableBuilder(
            listenable: roomProvider,
            builder: (context, body) => LobbyConnectionBand(
              // An idle lobby can let RTDB sleep; only an adopted room requires it.
              connectionChanges: roomProvider.isInRoom ? _serverConnection : null,
              child: body!,
            ),
            child: Scaffold(backgroundColor: ground, body: child),
          ),
          child: SafeArea(
            child: TabletLobbyLayout(
              header: StoreExit(
                progress: _storeExit,
                offset: const Offset(0, -2),
                child: _HomeHeader(
                  theme: theme,
                  onOpenStore: _openStore,
                  onBack: detail == null
                      ? null
                      : () => unawaited(_closeDetail()),
                  busy: _isStarting,
                ),
              ),
              content: StoreExit(
                progress: _storeExit,
                offset: const Offset(-1.15, 0.2),
                child: IgnorePointer(
                  ignoring: _isStarting,
                  child: TabletLobbyContentTransition(
                    child: detail == null
                        ? TabletGameShelf(
                            key: const ValueKey('lobby-shelf'),
                            gameProvider: gameProvider,
                            roomProvider: roomProvider,
                            selectedGameId: _selectedGameId,
                            theme: theme,
                            onlyPlayable: _onlyPlayable,
                            onOnlyPlayableChanged: (value) =>
                                setState(() => _onlyPlayable = value),
                            onSelect: (game) =>
                                setState(() => _selectedGameId = game.id),
                            onOpenDetail: _openDetail,
                            preparing: _isStarting,
                            selectedCoverKey: _selectedCoverKey,
                          )
                        : TabletGameDetailContent(
                            key: ValueKey('lobby-detail-${detail.id}'),
                            game: detail,
                            roomProvider: roomProvider,
                          ),
                  ),
                ),
              ),
              roomPanel: StoreExit(
                progress: _storeExit,
                offset: const Offset(1.2, 0.15),
                child: IgnorePointer(
                  ignoring: _isStarting,
                  child: TabletRoomPanel(
                    key: const ValueKey('lobby-room-panel'),
                    provider: roomProvider,
                    deep: theme.deep,
                    startBackground: theme.btnBg,
                    startForeground: theme.btnFg,
                    maxSlots: detail == null ? null : _maxSlots(detail),
                    startLoading: _isStarting,
                    onStart: () => unawaited(_startSelectedGame()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.theme,
    required this.onOpenStore,
    this.onBack,
    this.busy = false,
  });

  final MosiShelfTheme theme;
  final VoidCallback onOpenStore;
  final VoidCallback? onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: MosiButton(
                label: onBack == null
                    ? context.l10n.gameStore
                    : context.l10n.shelf,
                variant: MosiButtonVariant.outline,
                foreground: theme.fg,
                height: 44,
                fontSize: 15,
                radius: 6,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  onBack == null
                      ? Icons.shopping_bag_outlined
                      : Icons.chevron_left_rounded,
                ),
                onPressed: busy ? null : onBack ?? onOpenStore,
              ),
            ),
          ),
          MosiLogo(color: theme.fg),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocaleSettingsButton(
                    darkBackground: theme.fg == MosiColors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Profile(foreground: theme.fg)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
