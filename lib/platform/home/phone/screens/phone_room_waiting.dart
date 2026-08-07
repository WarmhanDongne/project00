import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
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
  late final Future<List<GameInfo>> _games;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: AnimatedBuilder(
          animation: widget.provider,
          builder: (context, _) {
            final players = widget.provider.players
                .where((players) => players.isActive)
                .toList(growable: false);
            final uids = widget.provider.players
                .map((players) => players.uid)
                .toList(growable: false);
            final selectedGameId = widget.provider.selectedGameId;
            final selectedGame = widget.provider.selectedGame;
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
                  hostName: '태블릿 방장',
                  participantsList: players
                      .map((player) => player.nickname)
                      .toList(growable: false),
                ),
                SizedBox(height: 36.h),
                groupGameText(selectedGameId, selectedGame),
                SizedBox(height: 10.h),

                if (selectedGameId == null || selectedGameId.isEmpty)
                  OwnGameList(games: _games)
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
