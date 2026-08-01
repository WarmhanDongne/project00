import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/providers/mobile_room_provider.dart';
import 'package:project00/platform/hub/screens/mobile_group_joined.dart';
import 'package:project00/platform/hub/widgets/mobile_participant_list.dart';

class MobileGroupInput extends StatefulWidget {
  const MobileGroupInput({super.key});

  @override
  State<MobileGroupInput> createState() => _MobileGroupInputState();
}

class _MobileGroupInputState extends State<MobileGroupInput> {
  final MobileRoomProvider _roomProvider = MobileRoomProvider();
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomProvider.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    FocusScope.of(context).unfocus();
    final joined = await _roomProvider.joinRoom(_roomCodeController.text);
    if (!mounted || joined) return;

    final message = _roomProvider.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('그룹 참여하기'), centerTitle: true),
          body: SafeArea(
            child: _roomProvider.isInRoom
                ? _JoinedRoom(provider: _roomProvider)
                : _JoinForm(
                    controller: _roomCodeController,
                    provider: _roomProvider,
                    onJoin: _joinRoom,
                  ),
          ),
        );
      },
    );
  }
}

class _JoinForm extends StatelessWidget {
  const _JoinForm({
    required this.controller,
    required this.provider,
    required this.onJoin,
  });

  final TextEditingController controller;
  final MobileRoomProvider provider;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text("그룹 참여하기")),
      body: DefaultTextStyle(
        style: TextStyle(
          fontSize: 25.sp,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              MobileParticipantList(
                hostName: '방장장',
                participantsList: ['플레이어', '잇츠미', '저예요'],
              ), // 참여자 목록
              SizedBox(height: 46.h),
              _buildNickNameAnnouncement(), // 닉네임 안내문구
              SizedBox(height: 19.h),
              _buildInsertNickName(), // 닉네임 삽입 및 확인 버튼
              SizedBox(height: 64.h),
              _buildEnterButton(), // 입장하기 버튼
            ],
          ),
        ),
      ),
    );
  }

  FilledButton _buildEnterButton() {
    return FilledButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MobileGroupJoined()),
        );
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.black,
        fixedSize: Size(164.w, 50.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.r)),
      ),
      child: Text(
        '입장하기',
        style: TextStyle(fontWeight: FontWeight.w400, fontSize: 25.sp),
      ),
    );
  }

  Padding _buildInsertNickName() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              // 닉네임 입력 받기
              height: 50.h,
              alignment: Alignment.centerLeft,
              color: Colors.grey,
              child: Text('닉네임 : 현재 닉네임'),
            ),
          ),
          SizedBox(width: 13.w),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.black,
              fixedSize: Size(66.w, 50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0.r),
              ),
              padding: EdgeInsets.zero,
            ),

            child: Text(
              '수정',
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 25.sp),
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildNickNameAnnouncement() {
    return Padding(
      padding: EdgeInsetsGeometry.symmetric(horizontal: 30.w),
      child: Center(
        child: Text(
          '해당 그룹에서 사용할 닉네임을 설정할 수 있습니다. (중복 불가)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
