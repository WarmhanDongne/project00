import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/screens/phone_game.dart'
    as final_call;
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart'
    as liars_poker;
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
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
  StreamSubscription<DatabaseEvent>? _gameStatusSubscription;
  String? _subscribedRoomCode;
  String? _subscribedGameId;
  bool _isOpeningGame = false;

  @override
  void initState() {
    super.initState();
    //=======================플랫폼 세로 화면 고정==============================
    unawaited(_lockPlatformPortrait());
    widget.provider.addListener(_syncGameStatusSubscription);
    _syncGameStatusSubscription();
  }

  Future<void> _lockPlatformPortrait() => AppOrientation.lockPlatformPortrait();

  void _syncGameStatusSubscription() {
    final roomCode = widget.provider.roomCode;
    final selectedGameId = widget.provider.selectedGameId;
    final isSupportedGame =
        selectedGameId == 'liars_poker' || selectedGameId == 'final_call';

    if (!isSupportedGame || roomCode == null) {
      unawaited(_gameStatusSubscription?.cancel());
      _gameStatusSubscription = null;
      _subscribedRoomCode = null;
      _subscribedGameId = null;
      return;
    }

    if (_subscribedRoomCode == roomCode &&
        _subscribedGameId == selectedGameId &&
        _gameStatusSubscription != null) {
      return;
    }

    unawaited(_gameStatusSubscription?.cancel());
    _subscribedRoomCode = roomCode;
    _subscribedGameId = selectedGameId;
    if (selectedGameId == 'final_call') {
      final finalCallService = FinalCallService();
      _gameStatusSubscription = finalCallService.query
          .watchStatus(roomCode)
          .listen((event) {
            if (event.snapshot.value == 'playing') {
              unawaited(_openFinalCall(roomCode, finalCallService));
            }
          }, onError: _showStatusError);
      return;
    }

    final gameService = LiarsPokerService();
    _gameStatusSubscription = gameService.query.watchStatus(roomCode).listen((
      event,
    ) {
      if (event.snapshot.value == 'playing') {
        unawaited(_openLiarsPoker(roomCode, gameService));
      }
    }, onError: _showStatusError);
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('게임 시작 상태를 확인하지 못했습니다: $error')));
  }

  Future<void> _openFinalCall(String roomCode, FinalCallService service) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;
    final leftRoom = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => final_call.PhoneGame(
          roomCode: roomCode,
          gameService: service,
          onExitRoom: widget.provider.leaveFinalCallGame,
        ),
      ),
    );
    _isOpeningGame = false;
    await _lockPlatformPortrait();
    if (!mounted) return;
    if (leftRoom == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openLiarsPoker(
    String roomCode,
    LiarsPokerService gameService,
  ) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;

    final leftRoom = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => liars_poker.PhoneGame(
          roomCode: roomCode,
          gameService: gameService,
          onExitRoom: widget.provider.leaveLiarsPokerGame,
        ),
      ),
    );

    _isOpeningGame = false;
    await _lockPlatformPortrait();
    if (!mounted) return;
    if (leftRoom == true && mounted) {
      // 참여 코드·닉네임·방 대기 경로를 모두 닫아 휴대폰 홈으로 이동합니다.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_syncGameStatusSubscription);
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
                    Navigator.of(context).pop();
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      PlatformNotice(
                        message: '태블릿에서 게임을 선택하면 자동으로 시작합니다.',
                        style: PlatformNoticeStyle.warning,
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
