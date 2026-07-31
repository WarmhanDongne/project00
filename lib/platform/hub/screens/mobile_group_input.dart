import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        child: Column(
          children: [
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 46.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("참여자 [ 4명 ]"), // n명 데이터 받아서 해야함.
                  SizedBox(height: 10.h),
                  Container(
                    height: 310.h,
                    width: 272.w,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    color: Colors.grey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("* 빵장장"),
                        Text("    - 플레이어"),
                        Text("    - 잇츠미"),
                        Text("    - 저예요"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 46.h),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 30.w),
              child: Center(
                child: Text(
                  '해당 그룹에서 사용할 닉네임을 설정할 수 있습니다. (중복 불가)',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 19.h),
            Row(
              children: [
                SizedBox(width: 35.w),
                Container(
                  width: 253.w,
                  height: 50.h,
                  alignment: Alignment.centerLeft,
                  color: Colors.grey,
                  child: Text('닉네임 : 현재 닉네임'),
                ),
                SizedBox(width: 13.w),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.black,
                  ),
                  child: Text('수정'),
                ),
              ],
            ),
            SizedBox(height: 64.h),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.black,
                fixedSize: Size(164.w, 50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0.r),
                ),
              ),
              child: Text('입장하기'),
            ),
          ],
        ),
      ),
    );
  }
}
