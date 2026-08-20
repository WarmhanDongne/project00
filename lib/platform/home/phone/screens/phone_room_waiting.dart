import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneRoomWaiting extends StatefulWidget {
  const PhoneRoomWaiting({super.key, required this.provider});

  final RoomProvider provider;

  @override
  State<PhoneRoomWaiting> createState() => _PhoneRoomWaitingState();
}

class _PhoneRoomWaitingState extends State<PhoneRoomWaiting> {
  StreamSubscription<String?>? _gameStatusSubscription;
  String? _subscribedRoomCode;
  String? _latestGameStatus;
  bool _isOpeningGame = false;

  @override
  void initState() {
    super.initState();
    //=======================플랫폼 세로 화면 고정==============================
    unawaited(_lockPlatformPortrait());
    widget.provider.addListener(_onRoomProviderChanged);
    // 마운트 시점에 이미 추방/방 종료 상태면 핸들러가 ModalRoute.of를
    // 호출하므로, initState 완료 전에 실행하지 않고 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRoomProviderChanged();
    });
  }

  Future<void> _lockPlatformPortrait() => AppOrientation.lockPlatformPortrait();

  void _onRoomProviderChanged() {
    final selectedGameId = widget.provider.selectedGameId;
    if (selectedGameId != null && selectedGameId.isNotEmpty) {
      //================상태바 표시=================
      // 태블릿의 게임 선택은 자리 배치 시작 신호이므로 휴대폰도 이때 전체 화면에 진입합니다.
      unawaited(AppSystemUi.enterGameFullscreen());
    }
    _syncGameStatusSubscription();

    final wasKicked = widget.provider.wasKicked;
    final wasRoomClosed = widget.provider.wasRoomClosed;

    if (wasKicked || wasRoomClosed) {
      widget.provider.wasKicked = false;
      widget.provider.wasRoomClosed = false;
      if (!mounted) return;
      // 방 대기 화면에서만 추방/해체를 감지하고 게임 중(isOpeningGame)일 때는 무시합니다.
      if (_isOpeningGame || ModalRoute.of(context)?.isCurrent != true) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(wasRoomClosed ? '방을 찾을 수 없습니다' : '방에서 추방되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      //================상태바 표시=================
      unawaited(AppSystemUi.showPlatformSystemBars());
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
    final selectedGameId = widget.provider.selectedGameId;
    if (selectedGameId == null) return;
    final game = GameRegistry.find(selectedGameId);
    if (game == null) return;
    unawaited(_openGame(roomCode, game));
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('게임 시작 상태를 확인하지 못했습니다: $error')));
  }

  Future<void> _openGame(String roomCode, TemplateGame game) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;

    // 휴대폰 방향은 게임 등록 정보가 단일 기준입니다. 새 게임에서 화면마다
    // 임의로 방향을 정하지 말고 TemplateGame.phoneOrientation을 선언하세요.
    unawaited(AppOrientation.applyPhoneGame(game.phoneOrientation));

    final leftRoom = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => game.buildPhoneScreen(
          roomCode: roomCode,
          onExitRoom: () => widget.provider.leaveGame(game.id),
        ),
      ),
    );

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
    unawaited(_lockPlatformPortrait());
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onRoomProviderChanged);
    _gameStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final selectedGameId = widget.provider.selectedGameId;
        final selectedGame = widget.provider.selectedGame;
        final players = widget.provider.players
            .where((player) => player.isActive)
            .toList(growable: false);
        final colors = context.platformColors;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                PhoneHeader(
                  buttonText: '그룹 나가기',
                  onPressed: () async {
                    final left = await widget.provider.leaveRoom();
                    if (!context.mounted || !left) return;
                    //================상태바 표시=================
                    unawaited(AppSystemUi.showPlatformSystemBars());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      _WaitingStatusBanner(
                        message:
                            selectedGameId == null || selectedGameId.isEmpty
                            ? '태블릿에서 게임을 선택하는 중입니다'
                            : '게임 시작을 기다리는 중입니다',
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            '참여 코드',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.provider.roomCode ?? '',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 22,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      PhoneRoomParticipantList(players: players),
                      const SizedBox(height: 24),
                      PlatformSectionTitle(
                        title: selectedGameId == null || selectedGameId.isEmpty
                            ? '그룹이 보유 중인 게임'
                            : '그룹이 선택한 게임',
                        trailing: Text(
                          selectedGameId == null || selectedGameId.isEmpty
                              ? '${widget.provider.groupGames.length}개'
                              : '시작 대기 중',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedGameId == null || selectedGameId.isEmpty)
                        if (widget.provider.groupGames.isEmpty)
                          PlatformPanel(
                            child: Text(
                              '그룹이 보유한 게임이 없습니다.',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          )
                        else
                          for (final game in widget.provider.groupGames)
                            PhoneGameCard(gameInfo: game, inset: false)
                      else if (selectedGame != null)
                        PhoneGameCard(gameInfo: selectedGame, inset: false)
                      else
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (widget.provider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        PlatformNotice(
                          message: widget.provider.errorMessage!,
                          style: PlatformNoticeStyle.danger,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingStatusBanner extends StatelessWidget {
  const _WaitingStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (_) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
