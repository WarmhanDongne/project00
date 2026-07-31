import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/screens/mobile_group_joined.dart';
import 'package:project00/platform/hub/widgets/mobile_participant_list.dart';

class MobileGroupInput extends StatefulWidget {
  const MobileGroupInput({super.key});

  @override
  State<MobileGroupInput> createState() => _MobileGroupInputState();
}

class _MobileGroupInputState extends State<MobileGroupInput> {
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
