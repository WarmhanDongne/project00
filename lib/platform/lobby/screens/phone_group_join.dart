/*
그룹 참여하기 - 방 입장화면. 
카메라를 통한 큐알 스캔 또는 참여 코드로 그룹에 입장하는 단계의 페이지.
*/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/lobby/screens/phone_group_input_name.dart';

class PhoneGroupJoin extends StatefulWidget {
  const PhoneGroupJoin({super.key});

  @override
  State<PhoneGroupJoin> createState() => _PhoneGroupJoinState();
}

class _PhoneGroupJoinState extends State<PhoneGroupJoin> {
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _openNameInput() {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length != 5) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('5자리 참여 코드를 입력해주세요.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneGroupInput(roomCode: roomCode),
      ),
    );
  }

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
              SizedBox(
                width: 342.w,
                child: TextField(
                  controller: _roomCodeController,
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'ABCDE',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _openNameInput(),
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

                  onPressed: _openNameInput,
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
