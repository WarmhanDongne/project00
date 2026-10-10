import 'package:project00/platform/localization/lobby_connection_band.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/widgets/game_exit_route.dart';
import 'package:game_kit/widgets/critical_network_guard.dart';
import 'package:game_kit/core/error/user_error_message.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_leave_button.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/home/phone/widgets/controller_reconnect_guard.dart';
import 'package:project00/platform/home/phone/widgets/lobby_reconnect_guard.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneRoomWaiting extends StatefulWidget {
  const PhoneRoomWaiting({
    super.key,
    required this.provider,
    this.headerForTesting,
  });

  final RoomProvider provider;
  @visibleForTesting
  final Widget? headerForTesting;

  @override
  State<PhoneRoomWaiting> createState() => _PhoneRoomWaitingState();
}

class _PhoneRoomWaitingState extends State<PhoneRoomWaiting> {
  StreamSubscription<String?>? _gameStatusSubscription;
  String? _subscribedRoomCode;
  String? _latestGameStatus;
  bool _isOpeningGame = false;
  bool _isHandlingForcedExit = false;

  @override
  void initState() {
    super.initState();
    //=======================플랫폼 세로 화면 고정==============================
    unawaited(_lockPlatformPortrait());
    unawaited(AppSystemUi.showPlatformSystemBars());
    widget.provider.addListener(_onRoomProviderChanged);
    // 마운트 시점에 이미 추방/방 종료 상태면 핸들러가 ModalRoute.of를
    // 호출하므로, initState 완료 전에 실행하지 않고 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRoomProviderChanged();
    });
  }

  Future<void> _lockPlatformPortrait() => AppOrientation.lockPlatformPortrait();

  void _onRoomProviderChanged() {
    _syncGameStatusSubscription();

    final wasKicked = widget.provider.wasKicked;
    final wasRoomClosed = widget.provider.wasRoomClosed;

    if ((wasKicked || wasRoomClosed) && !_isHandlingForcedExit) {
      if (!mounted) return;
      _isHandlingForcedExit = true;
      final terminationReason = widget.provider.roomTerminationReason;
      widget.provider.acknowledgeRoomExit();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wasKicked
                  ? '방에서 추방되었습니다.'
                  : terminationReason == RoomTerminationReason.closed
                  ? '방장이 방을 종료했습니다.'
                  : '방을 찾을 수 없습니다',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      //================상태바 표시=================
      unawaited(AppSystemUi.showPlatformSystemBars());
      // 게임 라우트가 현재 화면이어도 대기 화면의 context는 같은 Navigator에
      // 남아 있습니다. 종료 신호를 버리지 않고 게임·대기 경로를 한 번에 닫습니다.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _syncGameStatusSubscription() {
    final roomCode = widget.provider.roomCode;

    if (roomCode == null) {
      unawaited(_gameStatusSubscription?.cancel());
      _gameStatusSubscription = null;
      _subscribedRoomCode = null;
      _latestGameStatus = null;
      return;
    }

    if (_subscribedRoomCode == roomCode && _gameStatusSubscription != null) {
      _openGameIfReady(roomCode);
      return;
    }

    unawaited(_gameStatusSubscription?.cancel());
    _subscribedRoomCode = roomCode;
    _latestGameStatus = null;
    _gameStatusSubscription = widget.provider.watchGameStatus(roomCode).listen((
      status,
    ) {
      _latestGameStatus = status;
      _openGameIfReady(roomCode);
    }, onError: _showStatusError);
  }

  /// `selectedGame`과 `game/public/status`는 서로 다른 RTDB 경로이므로 도착
  /// 순서가 보장되지 않습니다. 두 값 중 어느 것이 먼저 와도 마지막 값을 보관했다가
  /// 모두 준비되는 순간 한 번만 게임 화면을 엽니다.
  void _openGameIfReady(String roomCode) {
    if (_latestGameStatus != 'playing' || _isOpeningGame || !mounted) return;
    // 방이 이미 끝났으면 낡은 playing 값입니다. 종료된 게임을 다시 열지 않습니다.
    if (widget.provider.isRoomFinished) return;
    final selectedGameId = widget.provider.selectedGameId;
    if (selectedGameId == null) return;
    final game = widget.provider.gameCatalog.find(selectedGameId);
    if (game == null) return;
    unawaited(_openGame(roomCode, game));
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    // 퇴장하면 내 참가자 노드가 사라져 game/public/status 읽기 권한도 함께
    // 사라집니다. 정상 퇴장으로 끝난 구독의 오류는 사용자 오류가 아닙니다.
    if (widget.provider.isLeaving || widget.provider.roomCode == null) return;
    final message = userErrorMessage(
      error,
      context: UserErrorContext.roomSubscription,
    );
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGame(String roomCode, TemplateGame game) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;

    try {
      if (!await prepareGameAssetsForRecovery(game, context)) {
        _isOpeningGame = false;
        await widget.provider.leaveGame(game.id);
        return;
      }
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '휴대폰 게임 에셋 확인');
      _isOpeningGame = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('게임 파일을 다운로드하지 못했습니다.')));
      return;
    }
    if (!mounted) {
      _isOpeningGame = false;
      return;
    }

    // 휴대폰 방향은 게임 등록 정보가 단일 기준입니다. 새 게임에서 화면마다
    // 임의로 방향을 정하지 말고 TemplateGame.phoneOrientation을 선언하세요.
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.applyPhoneGame(game.phoneOrientation));

    final gameRoute = GameExitMaterialPageRoute<bool>(
      builder: (gameContext) => CriticalNetworkGuard(
        provider: widget.provider,
        exitLabel: '게임과 그룹 나가기',
        onExit: () => unawaited(
          _leaveGameFromReconnect(gameContext: gameContext, game: game),
        ),
        child: ControllerReconnectGuard(
          provider: widget.provider,
          onExit: () => unawaited(
            _leaveGameFromReconnect(gameContext: gameContext, game: game),
          ),
          child: game.buildPhoneScreen(
            roomCode: roomCode,
            provider: widget.provider,
            onExitRoom: () => widget.provider.leaveGame(game.id),
          ),
        ),
      ),
    );
    final leftRoom = await Navigator.of(context).push<bool>(gameRoute);
    await gameRoute.completed;

    _isOpeningGame = false;
    if (!mounted) return;
    if (leftRoom == true) {
      // 참여 코드·닉네임·방 대기 경로를 모두 닫아 휴대폰 홈으로 이동합니다.
      //================상태바 표시=================
      unawaited(AppSystemUi.showPlatformSystemBars());
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // 화면 전환을 회전 응답보다 먼저 끝내 퇴장 성공 후 이전 화면에 갇히지
    // 않게 합니다. 방향 복원은 플랫폼 채널 응답을 기다리지 않습니다.
    unawaited(AppSystemUi.showPlatformSystemBars());
    unawaited(_lockPlatformPortrait());
  }

  Future<void> _leaveGameFromReconnect({
    required BuildContext gameContext,
    required TemplateGame game,
  }) async {
    final left = await widget.provider.leaveGame(game.id);
    if (!gameContext.mounted || !left) return;
    Navigator.of(gameContext).pop(true);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onRoomProviderChanged);
    _gameStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 뒤로가기로 이 화면만 닫히면 사용자는 로비에 있는데 서버에는
    // 참가자로 남습니다. 그 뒤 홈의 저장 세션 복원이 대기 화면을 다시 띄워
    // 방을 나온 것도 들어간 것도 아닌 상태가 됩니다. 나가려면 `그룹 나가기`를
    // 써야 하므로 뒤로가기는 삼킵니다(P-02).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('그룹에서 나가려면 화면 위쪽의 나가기를 눌러주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: LobbyConnectionBand(
        connectionChanges: _serverConnection,
        child: _buildBody(context),
      ),
    );
  }

  /// 아래 연결 띠가 듣는 서버 연결 상태입니다. 다시 그려도 같은 스트림을 씁니다.
  late final Stream<bool> _serverConnection = widget.provider
      .watchServerConnection();

  Widget _buildBody(BuildContext context) {
    return CriticalNetworkGuard(
      provider: widget.provider,
      onExit: () {
        unawaited(AppSystemUi.showPlatformSystemBars());
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: LobbyReconnectGuard(
        provider: widget.provider,
        onExit: () async {
          final left = await widget.provider.leaveRoom();
          if (!context.mounted || !left) return left;
          unawaited(AppSystemUi.showPlatformSystemBars());
          Navigator.of(context).popUntil((route) => route.isFirst);
          return true;
        },
        child: AnimatedBuilder(
          animation: widget.provider,
          builder: (context, _) {
            final selectedGameId = widget.provider.selectedGameId;
            // 게임이 끝난 방은 selectedGame이 그대로 남습니다. 종료 경로 어디에서도
            // 지우지 않기 때문입니다. 그 값만 보고 그리면 게임 소개가
            // 영원히 남아 대기실로 돌아오지 못합니다(P-02).
            //
            // 태블릿이 정리하기 전에도 화면이 갇히지 않도록 방 상태를 우선합니다.
            final hasSelectedGame =
                selectedGameId != null &&
                selectedGameId.isNotEmpty &&
                !widget.provider.isRoomFinished;
            final players = widget.provider.players
                .where((player) => player.isActive)
                .toList(growable: false);

            // 태블릿이 자리를 맞추는 동안에는 시안의 '자리 정하는 동안' 화면을
            // 보여 줍니다. 헤더(나가기)는 그대로 둡니다.
            final isSeating =
                hasSelectedGame && widget.provider.roomStatus == 'seating';
            if (isSeating) {
              return _PhoneSeatingView(
                provider: widget.provider,
                header:
                    widget.headerForTesting ??
                    _PhoneRoomHeader(
                      provider: widget.provider,
                      dark: true,
                      onPressed: () async {
                        final left = await widget.provider.leaveRoom();
                        if (!context.mounted || !left) return;
                        unawaited(AppSystemUi.showPlatformSystemBars());
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                    ),
              );
            }

            final scaffold = TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: hasSelectedGame
                    ? _WaitingGameColors.of(selectedGameId).ground
                    : MosiColors.violet,
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              builder: (context, color, child) =>
                  Scaffold(backgroundColor: color, body: child),
              child: SafeArea(
                // 흰 시트와 참여자 바는 화면 아래 끝까지 이어집니다.
                bottom: false,
                child: Column(
                  children: [
                    widget.headerForTesting ??
                        _PhoneRoomHeader(
                          provider: widget.provider,
                          dark: true,
                          onPressed: () async {
                            final left = await widget.provider.leaveRoom();
                            if (!context.mounted || !left) return;
                            //================상태바 표시=================
                            unawaited(AppSystemUi.showPlatformSystemBars());
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                        ),
                    Expanded(
                      child: _PhoneWaitingTransition(
                        child: hasSelectedGame
                            ? Column(
                                key: const ValueKey('phone-selected-game'),
                                children: [
                                  Expanded(
                                    child: _SelectedGameContent(
                                      provider: widget.provider,
                                    ),
                                  ),
                                  _WaitingPlayersBar(
                                    gameId: selectedGameId,
                                    players: players
                                        .where((player) => player.isPlayer)
                                        .toList(growable: false),
                                  ),
                                ],
                              )
                            : KeyedSubtree(
                                key: const ValueKey('phone-group-waiting'),
                                child: _GroupWaitingContent(
                                  provider: widget.provider,
                                  players: players,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            final lightBars =
                !hasSelectedGame ||
                _WaitingGameColors.of(selectedGameId).darkGround;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: lightBars
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: scaffold,
            );
          },
        ),
      ),
    );
  }
}

class _PhoneRoomHeader extends StatelessWidget {
  const _PhoneRoomHeader({
    required this.provider,
    required this.onPressed,
    this.dark = false,
  });

  final RoomProvider provider;
  final VoidCallback onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final code = provider.roomCode;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : MosiColors.white,
        border: dark
            ? null
            : const Border(bottom: BorderSide(color: MosiColors.ink, width: 3)),
      ),
      child: Row(
        children: [
          PhoneRoomLeaveButton(provider: provider, onPressed: onPressed),
          const Spacer(),
          if (code != null) ...[
            _PhoneRoomCode(
              code: code,
              color: provider.selectedGameId?.isNotEmpty == true
                  ? MosiGameArt.of(provider.selectedGameId!).shelfTheme.btnBg
                  : MosiColors.sun,
            ),
          ],
        ],
      ),
    );
  }
}

/// 작은 ROOM 라벨과 코드를 하나의 색 배지로 묶습니다.
class _PhoneRoomCode extends StatelessWidget {
  const _PhoneRoomCode({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '방 코드 ${code.split('').join(' ')}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        width: 94,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MosiColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: MosiColors.navy, offset: Offset(3, 3)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROOM',
                style: MosiFonts.grotesk(
                  size: 8,
                  color: MosiColors.navy,
                  letterSpacing: 2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                code,
                style: MosiFonts.grotesk(
                  size: 18,
                  color: MosiColors.navy,
                  letterSpacing: 1.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 게임을 고르기 전 대기실입니다. 위는 보라 바탕의 안내, 아래는 흰 시트에
/// 참여자와 그룹 게임을 둡니다(연결 끊김 화면과 같은 장면+시트 구성).
class _GroupWaitingContent extends StatelessWidget {
  const _GroupWaitingContent({required this.provider, required this.players});

  final RoomProvider provider;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final finished = provider.isRoomFinished;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WaitingHero(
          title: finished ? '게임이 끝났어요' : '태블릿에서 게임을\n고르는 중이에요',
          message: finished ? '태블릿에서 다음 게임을 고르는 중입니다' : '고르면 이 화면이 바로 바뀌어요',
          characterIds: [for (final player in players) player.characterId],
        ),
        Expanded(
          // 위쪽 테두리만 검은 선으로 보이도록 검은 판 위에 흰 판을 3px 내려 겹칩니다.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MosiColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: ColoredBox(
                  color: MosiColors.white,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 26, 24, 28 + bottomInset),
                    children: [
                      PhoneRoomParticipantList(players: players),
                      const SizedBox(height: 28),
                      _SheetSectionTitle(
                        title: '그룹이 보유 중인 게임',
                        count:
                            provider.groupGamesLoadStatus ==
                                RoomDataLoadStatus.loaded
                            ? '${provider.groupGames.length}개'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _GroupGamesContent(provider: provider),
                      if (provider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        PlatformNotice(
                          message: provider.errorMessage!,
                          style: PlatformNoticeStyle.danger,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title, this.count});

  final String title;
  final String? count;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        title,
        style: MosiFonts.sans(
          size: 18,
          weight: FontWeight.w700,
          color: MosiColors.navy,
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Text(
          count!,
          style: MosiFonts.grotesk(
            size: 14,
            weight: FontWeight.w700,
            color: MosiColors.violet,
          ),
        ),
      ],
    ],
  );
}

/// 보라 바탕 위의 큰 안내 문구와 참여자 얼굴 묶음입니다.
class _WaitingHero extends StatelessWidget {
  const _WaitingHero({
    required this.title,
    required this.message,
    required this.characterIds,
  });

  final String title;
  final String message;
  final List<String> characterIds;

  @override
  Widget build(BuildContext context) {
    final faces = characterIds.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MosiColors.sun,
                    border: Border.all(color: MosiColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '대기실',
                    style: MosiFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: MosiColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: MosiFonts.sans(
                    size: 25,
                    weight: FontWeight.w700,
                    color: MosiColors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                _WaitingStatusBanner(message: message),
              ],
            ),
          ),
          if (faces.isNotEmpty) ...[
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: SizedBox(
                width: 55 + (faces.length - 1) * 20,
                height: 67,
                child: Stack(
                  children: [
                    for (final (i, id) in faces.indexed)
                      Positioned(
                        left: i * 20,
                        top: i.isEven ? 0 : 12,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: MosiColors.violetDeep,
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          child: MosiFace(
                            characterId: id,
                            size: 52,
                            ring: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 흰 시트 안의 크림색 안내 판입니다.
class _SheetPaper extends StatelessWidget {
  const _SheetPaper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: MosiColors.paper,
      border: Border.all(color: MosiColors.ink, width: 2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _GroupGamesContent extends StatelessWidget {
  const _GroupGamesContent({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    if (provider.groupGamesLoadStatus == RoomDataLoadStatus.idle ||
        provider.groupGamesLoadStatus == RoomDataLoadStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: MosiColors.lime)),
      );
    }
    if (provider.groupGamesLoadStatus == RoomDataLoadStatus.failure) {
      return _SheetPaper(
        child: Column(
          children: [
            Text(
              provider.groupGamesError ?? '게임 목록을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            MosiButton(
              label: '다시 시도',
              expand: false,
              background: MosiColors.lime,
              foreground: MosiColors.ink,
              shadowColor: MosiColors.ink,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onPressed: provider.retryGroupGames,
            ),
          ],
        ),
      );
    }
    if (provider.groupGames.isEmpty) {
      return _SheetPaper(
        child: Text(
          '그룹이 보유한 게임이 없습니다.',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final game in provider.groupGames)
          PhoneGameCard(gameInfo: game, inset: false),
      ],
    );
  }
}

/// 선택한 게임의 선반 테마 색입니다. 위쪽은 게임 색 바탕, 아래 흰 시트는
/// 남색 글자를 쓰고 강조만 게임 색에서 가져옵니다.
class _WaitingGameColors {
  const _WaitingGameColors(this.theme);

  factory _WaitingGameColors.of(String? gameId) =>
      _WaitingGameColors(MosiGameArt.of(gameId ?? '').shelfTheme);

  final MosiShelfTheme theme;

  Color get ground => theme.ground;

  /// 게임 색 바탕 위의 글자색입니다.
  Color get fg => theme.fg;
  bool get darkGround => theme.ground.computeLuminance() < .4;

  /// 흰 시트 위 글자색입니다.
  Color get ink => MosiColors.navy;
  Color get muted => MosiColors.muted;

  /// 흰 시트 위 강조색입니다. 밝은 게임 색은 흰 바탕에서 읽히지 않아 진한 색을 씁니다.
  Color get accent => darkGround ? theme.ground : theme.deep;
  Color get shadow => theme.deep;
  Color get button => theme.btnBg;
  Color get buttonFg => theme.btnFg;
}

/// 헤더를 고정하고 본문만 짧게 섞어 바꿉니다. 퇴장 중인 화면은 조작하지 않습니다.
class _PhoneWaitingTransition extends StatelessWidget {
  const _PhoneWaitingTransition({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      reverseDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 12 * (1 - animation.value)),
            child: child,
          ),
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previous)
            ExcludeFocus(
              child: ExcludeSemantics(child: IgnorePointer(child: child)),
            ),
          ?current,
        ],
      ),
      child: child,
    ),
  );
}

class _SelectedGameContent extends StatelessWidget {
  const _SelectedGameContent({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return _PhoneWaitingTransition(child: _content());
  }

  Widget _content() {
    final id = provider.selectedGameId;
    final game =
        provider.selectedGame ??
        (provider.selectedGameLoadStatus != RoomDataLoadStatus.failure
            ? provider.groupGames.where((game) => game.id == id).firstOrNull
            : null);
    if (game != null) {
      return _SelectedGameDetails(
        key: ValueKey('phone-game-details-${game.id}'),
        gameInfo: game,
      );
    }

    if (provider.selectedGameLoadStatus == RoomDataLoadStatus.failure) {
      return Center(
        key: ValueKey('phone-game-error-$id'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PlatformPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.selectedGameError ?? '게임 정보를 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                PlatformButton(
                  label: '다시 시도',
                  expand: false,
                  style: PlatformButtonStyle.secondary,
                  onPressed: provider.retrySelectedGame,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colors = _WaitingGameColors.of(provider.selectedGameId);
    return Center(
      key: ValueKey('phone-game-loading-$id'),
      child: CircularProgressIndicator(color: colors.fg),
    );
  }
}

class _SelectedGameDetails extends StatelessWidget {
  const _SelectedGameDetails({super.key, required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final colors = _WaitingGameColors.of(gameInfo.id);
    final rules = gameInfo.rules.trim().isEmpty
        ? '게임 규칙을 준비 중입니다.'
        : gameInfo.rules;
    return CustomScrollView(
      slivers: [
        // 게임 색 바탕 위: 표지와 소개
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.button,
                    border: Border.all(color: MosiColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '그룹이 선택한 게임',
                    style: MosiFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: colors.buttonFg,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final coverWidth = (constraints.maxWidth * 0.4).clamp(
                      110.0,
                      170.0,
                    );
                    final details = _SelectedGameSummary(gameInfo: gameInfo);
                    final cover = MosiGameCover(
                      gameId: gameInfo.id,
                      width: coverWidth,
                      fallbackName: gameInfo.name,
                      fallbackImageUrl: gameInfo.imageUrl,
                      shadowColor: MosiColors.ink,
                    );
                    if (constraints.maxWidth < 330) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: cover),
                          const SizedBox(height: 18),
                          details,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cover,
                        const SizedBox(width: 20),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 흰 시트: 게임 규칙. 규칙이 짧아도 시트가 화면 아래까지 이어집니다.
        SliverFillRemaining(
          hasScrollBody: false,
          child: DecoratedBox(
            // 위쪽 테두리만 검은 선으로 보이도록 검은 판 위에 흰 판을 3px 내려 겹칩니다.
            decoration: const BoxDecoration(
              color: MosiColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: MosiColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '게임 규칙',
                      style: MosiFonts.sans(
                        size: 18,
                        weight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MosiColors.paper,
                        border: Border.all(color: MosiColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        rules,
                        style: MosiFonts.sans(
                          size: 14,
                          color: MosiColors.ink2,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedGameSummary extends StatelessWidget {
  const _SelectedGameSummary({required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(gameInfo.id, fallbackName: gameInfo.name);
    final known = MosiGameArt.isKnown(gameInfo.id);
    final colors = _WaitingGameColors.of(gameInfo.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          known ? art.koreanName : gameInfo.name,
          style: MosiFonts.sans(
            size: 26,
            height: 1.15,
            weight: FontWeight.w700,
            color: colors.fg,
          ),
        ),
        if (known)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              art.englishName,
              style: MosiFonts.grotesk(
                size: 11,
                weight: FontWeight.w700,
                color: colors.darkGround ? colors.button : colors.shadow,
                letterSpacing: 2.5,
              ),
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (gameInfo.playTime > 0)
              MosiPill(
                label: '${gameInfo.playTime}분',
                fontSize: 13,
                color: colors.fg,
                borderColor: colors.fg,
              ),
            if (gameInfo.minPlayers > 0)
              MosiPill(
                label: '${gameInfo.minPlayers}–${gameInfo.maxPlayers}명',
                fontSize: 13,
                color: colors.fg,
                borderColor: colors.fg,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          gameInfo.description,
          style: MosiFonts.sans(
            color: colors.fg.withValues(alpha: .82),
            size: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _WaitingPlayersBar extends StatelessWidget {
  const _WaitingPlayersBar({required this.gameId, required this.players});

  final String gameId;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final colors = _WaitingGameColors.of(gameId);
    final reconnecting = players.where((player) => !player.isConnected).length;
    final nameHeight = MediaQuery.textScalerOf(context).scale(12) * 1.3;
    return Container(
      key: const Key('waiting-players-bar'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: MosiColors.white,
        border: Border(top: BorderSide(color: MosiColors.ink, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '함께하는 사람 ',
                    children: [
                      TextSpan(
                        text: '${players.length}',
                        style: TextStyle(color: colors.accent),
                      ),
                    ],
                  ),
                  style: MosiFonts.sans(
                    size: 15,
                    weight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              if (reconnecting > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$reconnecting명 재연결 중',
                  style: MosiFonts.sans(size: 11, color: colors.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            Text(
              '아직 참가자가 없습니다.',
              style: MosiFonts.sans(size: 12, color: colors.muted),
            )
          else
            SizedBox(
              height: 58 + nameHeight,
              child: ListView.separated(
                key: const Key('waiting-players-scroll'),
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final player = players[index];
                  return Semantics(
                    key: ValueKey('waiting-player-${player.uid}'),
                    label:
                        '${player.nickname}, ${player.isConnected ? '연결됨' : '재연결 중'}',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Opacity(
                            opacity: player.isConnected ? 1 : .45,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: player.isConnected
                                      ? colors.button
                                      : MosiColors.navyFaint,
                                  width: 2,
                                ),
                              ),
                              child: MosiFace(
                                characterId: player.characterId,
                                size: 42,
                                ring: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            player.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: MosiFonts.sans(
                              size: 12,
                              weight: FontWeight.w700,
                              color: colors.ink,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

//=======================자리 정하는 동안 (휴대폰)==============================
class _PhoneSeatingView extends StatefulWidget {
  const _PhoneSeatingView({required this.provider, required this.header});

  final RoomProvider provider;
  final Widget header;

  @override
  State<_PhoneSeatingView> createState() => _PhoneSeatingViewState();
}

class _PhoneSeatingViewState extends State<_PhoneSeatingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final gameId = provider.selectedGameId;
    final theme = MosiSeatTheme.of(gameId);
    final darkTable = theme.table.computeLuminance() < .4;
    final foreground = darkTable ? MosiColors.white : MosiColors.navy;
    final soft = Color.lerp(foreground, theme.table, .25)!;
    final game = provider.selectedGame;
    final art = MosiGameArt.of(gameId ?? '', fallbackName: game?.name);
    final gameName = gameId != null && MosiGameArt.isKnown(gameId)
        ? art.koreanName
        : game?.name ?? '게임';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final me = provider.players
        .where((player) => player.uid == uid)
        .firstOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkTable ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: theme.table,
        body: CustomPaint(
          painter: _DotGridPainter(color: foreground.withValues(alpha: .07)),
          child: SafeArea(
            child: Column(
              children: [
                widget.header,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          '$gameName · 대기실',
                          style: MosiFonts.sans(size: 14, color: soft),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '태블릿에서\n자리를 맞추고 있어요',
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 24,
                            weight: FontWeight.w700,
                            color: foreground,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 36),
                        MosiBox(
                          width: 240,
                          padding: const EdgeInsets.all(22),
                          radius: 18,
                          shadowOffset: 8,
                          shadowColor: theme.deep,
                          child: Column(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.deep,
                                      offset: const Offset(5, 5),
                                    ),
                                  ],
                                ),
                                child: MosiFace(
                                  characterId: me?.characterId,
                                  size: 104,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                me?.nickname ?? '',
                                style: MosiFonts.sans(
                                  size: 20,
                                  weight: FontWeight.w700,
                                  color: MosiColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '내 이름 카드가 내가 앉은 쪽에\n오면 돼요',
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 14,
                            color: soft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AnimatedBuilder(
                    animation: _dots,
                    builder: (context, _) {
                      final active = (_dots.value * 3).floor();
                      return Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '방장이 완료를 누르면 시작해요 '),
                            for (var i = 0; i < 3; i++)
                              TextSpan(
                                text: '·',
                                style: TextStyle(
                                  color: soft.withValues(
                                    alpha: i == active ? 1 : 0.25,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        style: MosiFonts.sans(size: 13, color: soft),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 15.0; y < size.height; y += 30) {
      for (var x = 15.0; x < size.width; x += 30) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 보라 바탕 위에서 깜빡이는 점과 함께 기다리는 중임을 알립니다.
class _WaitingStatusBanner extends StatefulWidget {
  const _WaitingStatusBanner({required this.message});

  final String message;

  @override
  State<_WaitingStatusBanner> createState() => _WaitingStatusBannerState();
}

class _WaitingStatusBannerState extends State<_WaitingStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final activeIndex = (_controller.value * 3).floor().clamp(0, 2);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Container(
                  key: ValueKey('waiting-dot-$index'),
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: index == activeIndex
                        ? MosiColors.sun
                        : MosiColors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.message,
            style: MosiFonts.sans(
              color: const Color(0xFFD9D1EE),
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
