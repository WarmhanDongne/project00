import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/*
사용 파일
phone_room_input에
*/

class PhoneRoomParticipantList extends StatelessWidget {
  int get totalParticipants => participantsList.length; // 참여자
  final String hostName;
  final List<String> participantsList;

  const PhoneRoomParticipantList({
    super.key,
    required this.hostName,
    required this.participantsList,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 25.sp,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 46.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("참여자 [ $totalParticipants명 ]"),
            SizedBox(height: 10.h),
            Container(
              height: 310.h,
              width: 272.w,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              color: Colors.grey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("* $hostName"),
                  ...participantsList.map((name) => Text("    - $name")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
