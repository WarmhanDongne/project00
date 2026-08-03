/*
그룹 참여하기 - 방 입장화면. 
카메라를 통한 큐알 스캔 또는 참여 코드로 그룹에 입장하는 단계의 페이지.
*/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';

class PhoneRoomJoin extends StatefulWidget {
  const PhoneRoomJoin({super.key});

  @override
  State<PhoneRoomJoin> createState() => _PhoneRoomJoinState();
}

class _PhoneRoomJoinState extends State<PhoneRoomJoin> {
  final TextEditingController _roomCodeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isOpeningNameInput = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _openNameInput() async {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length != 5) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('5자리 참여 코드를 입력해주세요.')));
      return;
    }

    if (_isOpeningNameInput) return;
    _isOpeningNameInput = true;

    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라 사용이 불가능해도 참여 코드를 직접 입력해 입장할 수 있습니다.
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneRoomNickname(
          roomCode: roomCode,
        ), // 입력 완료 버튼 클릭 후 받고 처리한 roomCode를 파라미터로 주고 PhoneRoomInput로 이동
      ),
    );

    if (!mounted) return;
    _isOpeningNameInput = false;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // 권한이 거부된 경우에도 수동 코드 입력 기능은 계속 사용할 수 있습니다.
    }
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
                child: joinGuidance(),
              ),
              SizedBox(height: 26.h),
              cameraSection(),
              SizedBox(height: 36.h),
              Divider(color: Colors.grey, thickness: 1.0, height: 20.h),
              enterJoinCode(),
              enterJoinCodeSection(),
              SizedBox(height: 36.h),
              submitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Container cameraSection() {
    return Container(
      height: 310.h,
      width: 310.w,
      color: Colors.grey,
      child: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (_isOpeningNameInput) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              final scannedCode = barcode.rawValue!.trim().toUpperCase();
              if (scannedCode.length == 5) {
                _roomCodeController.text = scannedCode;
                // 스캔 성공 시 닉네임 수정으로 이동
                _openNameInput();
                break;
              }
            }
          }
        },
      ),
    );
  }

  SizedBox enterJoinCodeSection() {
    return SizedBox(
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
    );
  }

  SizedBox submitButton() {
    return SizedBox(
      width: 164.w,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.grey,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0.r),
          ),
        ),

        onPressed: _openNameInput,
        child: Text('입력 완료'),
      ),
    );
  }

  Column enterJoinCode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsGeometry.only(left: 30.w),
          child: Text(
            "참여 코드 입력",
            style: TextStyle(fontSize: 25.sp, fontWeight: FontWeight.w400),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Text joinGuidance() {
    return Text(
      "테블릿에 표시된 QR 코드를 스캔, 혹은 참여 코드를 입력해 주세요. ",
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.w400, fontSize: 25.sp),
    );
  }
}
