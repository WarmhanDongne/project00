import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class PhoneRoomNickname extends StatefulWidget {
  const PhoneRoomNickname({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<PhoneRoomNickname> createState() => _PhoneRoomNickname();
}

class _PhoneRoomNickname extends State<PhoneRoomNickname> {
  final RoomProvider _roomProvider = RoomProvider();
  late final TextEditingController _roomCodeController;

  @override
  void initState() {
    super.initState();
    _roomCodeController = TextEditingController(text: widget.roomCode);
  }

  @override
  void dispose() {
    _roomProvider.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  // _JoinForm에 onJoin: _joinRoom으로 주입.
  Future<void> _joinRoom() async {
    // 자동으로 키보드 화면 내리기
    FocusScope.of(context).unfocus();
    // 방 입장 트랜잭션 요청
    final joined = await _roomProvider.joinRoom(_roomCodeController.text);

    // 비동기 작업 후 현재 화면에 머물러 있는지 검사
    if (!mounted) return;

    // 트랜잭션 결과에 따른 분기
    if (joined) {
      // 성공 시 그룹 입장
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhoneRoomWaiting(provider: _roomProvider),
        ),
      );
    } else {
      // 실패 시 에러 메세지 렌더
      final message = _roomProvider.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    /*
    1. 초기 진입 시: _roomProvider.isInRoom이 false이므로 _JoinForm 렌더링.
    2. 입장하기 클릭:  올바른 코드일 경우 _roomProvider.isInRoom가 true로 바뀌며 notifyListeners() 호출
    3. AnimatedBuilder가 상태변화 감지 후 isInRoom == true. PhoneRoomWaiting를 렌더링한다.
     */
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) {
        if (_roomProvider.isInRoom) {
          return PhoneRoomWaiting(provider: _roomProvider);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('그룹 참여하기'), centerTitle: true),
          body: SafeArea(
            child: _JoinForm(
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
  final RoomProvider provider;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nickname = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? '사용자';

    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 25.sp,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              '참여 코드: ${controller.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            PhoneRoomParticipantList(
              hostName: '태블릿 방장',
              participantsList: [nickname],
            ),
            SizedBox(height: 46.h),
            _buildNickNameAnnouncement(),
            SizedBox(height: 19.h),
            _buildInsertNickName(nickname),
            if (provider.errorMessage != null) ...[
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            SizedBox(height: 64.h),
            _buildEnterButton(),
          ],
        ),
      ),
    );
  }

  FilledButton _buildEnterButton() {
    return FilledButton(
      onPressed: provider.isLoading ? null : onJoin,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.black,
        fixedSize: Size(164.w, 50.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.r)),
      ),
      child: provider.isLoading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '입장하기',
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 25.sp),
            ),
    );
  }

  Padding _buildInsertNickName(String nickname) {
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
              child: Text('닉네임 : $nickname'),
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
