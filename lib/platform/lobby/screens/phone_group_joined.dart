import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/home/models/game_info.dart';
import 'package:project00/platform/lobby/providers/phone_room_provider.dart';
import 'package:project00/platform/home/services/game_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_group_top_bar.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/lobby/widgets/phone_participant_list.dart';

class PhoneGroupJoined extends StatefulWidget {
  const PhoneGroupJoined({super.key, required this.provider});

  final PhoneRoomProvider provider;

  @override
  State<PhoneGroupJoined> createState() => _PhoneGroupJoinedState();
}

class _PhoneGroupJoinedState extends State<PhoneGroupJoined> {
  late final Future<List<GameInfo>> _games;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.provider.members
        .where((member) => member.isActive)
        .toList(growable: false);
    final selectedGameId = widget.provider.room?.selectedGameId;

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  GroupTopBar(
                    buttonText: "그룹 나가기",
                    onPressed: () async {
                      final left = await widget.provider.leaveRoom();
                      if (!context.mounted || !left) return;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 26.h),
            Text(
              '방 코드: ${widget.provider.roomCode ?? ''}',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            PhoneParticipantList(
              hostName: '태블릿 방장',
              participantsList: members
                  .map((member) => member.nickname)
                  .toList(growable: false),
            ),
            SizedBox(height: 36.h),
            Row(
              children: [
                SizedBox(width: 18.w),
                Text(
                  '그룹이 보유 중인 게임',
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            if (selectedGameId != null && selectedGameId.isNotEmpty)
              Text('선택된 게임: $selectedGameId', style: TextStyle(fontSize: 22.sp))
            else
              OwnGameList(games: _games),
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
        ),
      ),
    );
  }
}
