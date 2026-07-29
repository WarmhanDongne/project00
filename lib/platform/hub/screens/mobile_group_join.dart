/*
그룹 참여하기 - 방 입장화면. 
카메라를 통한 큐알 스캔 또는 참여 코드로 그룹에 입장하는 단계의 페이지.
*/
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/screens/mobile_group_input.dart';

class MobileGroupJoin extends StatefulWidget {
  const MobileGroupJoin({super.key});

  @override
  State<MobileGroupJoin> createState() => _MobileGroupJoinState();
}

class _MobileGroupJoinState extends State<MobileGroupJoin> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: Text("그룹 참여하기")),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 23.w),
                child: Text(
                  "테블릿에 표시된 QR 코드를 스캔, 혹은 참여 코드를 입력해 주세요. ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 25.sp,
                  ),
                ),
              ),
              SizedBox(height: 26.h),
              Container(
                height: 310.h,
                width: 310.w,
                color: Colors.grey,
                child: Center(child: Text('카메라')),
              ),
              SizedBox(height: 36.h),
              Text(
                "--------------- OR --------------",
                style: TextStyle(fontWeight: FontWeight(400), fontSize: 25.sp),
              ),
              SizedBox(height: 20.h),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsGeometry.only(left: 30.w),
                    child: Text(
                      "참여 코드 입력",
                      style: TextStyle(
                        fontSize: 25.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
              Container(
                height: 126.h,
                width: 342.w,
                color: Colors.grey,
                child: Center(
                  child: Text(
                    '_______ _______ _______ _______ _______ ________',
                  ),
                ),
              ),
              SizedBox(height: 36.h),
              SizedBox(
                width: 164.w,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0.r),
                    ),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileGroupInput(),
                      ),
                    );
                  },
                  child: Text('입력 완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
