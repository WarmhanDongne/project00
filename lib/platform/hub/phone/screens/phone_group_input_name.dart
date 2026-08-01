import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/phone/providers/phone_room_provider.dart';
import 'package:project00/platform/hub/phone/screens/phone_group_joined.dart';
import 'package:project00/platform/hub/phone/widgets/phone_participant_list.dart';

class PhoneGroupInput extends StatefulWidget {
  const PhoneGroupInput({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<PhoneGroupInput> createState() => _PhoneGroupInputState();
}

class _PhoneGroupInputState extends State<PhoneGroupInput> {
  final PhoneRoomProvider _roomProvider = PhoneRoomProvider();
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
        if (_roomProvider.isInRoom) {
          return PhoneGroupJoined(provider: _roomProvider);
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
  final PhoneRoomProvider provider;
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
            PhoneParticipantList(
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
            onPressed: null,
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
