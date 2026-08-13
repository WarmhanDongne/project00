import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/final_call/screens/phone/final_call_phone_game.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';

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
    widget.provider.addListener(_syncGameStatusSubscription);
    _syncGameStatusSubscription();
  }

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
      _gameStatusSubscription = finalCallService.watchPublic(roomCode).listen((
        event,
      ) {
        final value = event.snapshot.value;
        if (value is Map && value['status'] == 'playing') {
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
        builder: (_) => FinalCallPhoneGame(
          roomCode: roomCode,
          service: service,
          onExitRoom: widget.provider.leaveFinalCallGame,
        ),
      ),
    );
    _isOpeningGame = false;
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
        builder: (_) => PhoneGame(
          roomCode: roomCode,
          gameService: gameService,
          onExitRoom: widget.provider.leaveLiarsPokerGame,
        ),
      ),
    );

    _isOpeningGame = false;
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
    return SafeArea(
      child: Scaffold(
        body: AnimatedBuilder(
          animation: widget.provider,
          builder: (context, _) {
            final selectedGameId = widget.provider.selectedGameId;
            final selectedGame = widget.provider.selectedGame;
            final players = widget.provider.players
                .where((player) => player.isActive)
                .toList(growable: false);

            return Column(
              children: [
                PhoneHeader(
                  buttonText: "그룹 나가기",
                  onPressed: () async {
                    final left = await widget.provider.leaveRoom();
                    if (!context.mounted || !left) return;
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: 26.h),
                Text(
                  '방 코드: ${widget.provider.roomCode ?? ''}',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                PhoneRoomParticipantList(
                  participantsList: players
                      .map((player) => player.nickname)
                      .toList(growable: false),
                ),
                SizedBox(height: 36.h),
                groupGameText(selectedGameId, selectedGame),
                SizedBox(height: 10.h),
                // 경우에 따른 게임 화면 로딩 파트
                if (selectedGameId == null || selectedGameId.isEmpty)
                  PhoneOwnGameList(
                    games: Future.value(widget.provider.groupGames),
                  )
                else if (selectedGame != null)
                  PhoneGameCard(gameInfo: widget.provider.selectedGame!)
                else
                  const Center(child: CircularProgressIndicator()),

                if (widget.provider.errorMessage != null)
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      widget.provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Row groupGameText(String? selectedGameId, GameInfo? selectedGame) {
    return Row(
      children: [
        SizedBox(width: 18.w),
        if (selectedGameId == null || selectedGameId.isEmpty)
          Text(
            '그룹이 보유 중인 게임',
            style: TextStyle(fontSize: 25.sp, fontWeight: FontWeight.w400),
          )
        else if (selectedGame != null)
          Text(
            '그룹이 선택한 게임',
            style: TextStyle(fontSize: 25.sp, fontWeight: FontWeight.w400),
          ),
      ],
    );
  }
}
