import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/screens/mobile_group_join.dart';
import 'package:project00/platform/hub/widgets/mobile_group_top_bar.dart';

class MobileGroupJoined extends StatefulWidget {
  const MobileGroupJoined({super.key});

  @override
  State<MobileGroupJoined> createState() => _MobileGroupJoinedState();
}

class _MobileGroupJoinedState extends State<MobileGroupJoined> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 10.h),
          GroupTopBar(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MobileGroupJoin()),
              );
            },
          ),
        ],
      ),
    );
  }
}
