import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/screens/mobile_group_join.dart';
import 'package:project00/platform/hub/widgets/mobile_group_top_bar.dart';
import 'package:project00/platform/hub/widgets/mobile_participant_list.dart';

class MobileGroupJoined extends StatefulWidget {
  const MobileGroupJoined({super.key});

  @override
  State<MobileGroupJoined> createState() => _MobileGroupJoinedState();
}

class _MobileGroupJoinedState extends State<MobileGroupJoined> {
  @override
  Widget build(BuildContext context) {
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileGroupJoin(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 26.h),
            MobileParticipantList(
              hostName: '빵장장',
              participantsList: ['플레이어', '잇츠미', '저예요', '본인'],
            ),
            SizedBox(height: 36.h),
          ],
        ),
      ),
    );
  }
}
