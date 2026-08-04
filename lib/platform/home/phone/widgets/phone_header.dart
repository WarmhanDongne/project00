import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/home/tablet/screens/tablet_home.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_button.dart';

class PhoneHeader extends StatelessWidget {
  final VoidCallback onPressed;
  final String buttonText;

  const PhoneHeader({
    super.key,
    required this.onPressed,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          // 그룹 참여
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.grey[300],
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 10.0.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            buttonText,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
        AppButton(
          text: 'Logout',
          width: 110.w,
          backgroundColor: Colors.blue,
          onPressed: logout,
        ),
        Ink(
          width: 50.w,
          height: 50.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage("https://picsum.photos/600/400"),
              fit: BoxFit.cover,
            ),
          ),
          child: InkWell(customBorder: CircleBorder(), onTap: () {}),
        ),
      ],
    );
  }
}
