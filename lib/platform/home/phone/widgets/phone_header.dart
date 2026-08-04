import 'package:firebase_auth/firebase_auth.dart';
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
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL;
    final hasPhoto = photoURL != null && photoURL.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        groupButton(), // 그룹 참여하기 or 그룹 나가기 버튼.
        logoutButton(),
        GestureDetector(
          onTap: () {},
          child: CircleAvatar(
            radius: 25.r,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: hasPhoto ? NetworkImage(photoURL) : null,
            child: hasPhoto
                ? null
                : const Icon(Icons.person, color: Colors.white),
          ),
        ),
      ],
    );
  }

  AppButton logoutButton() {
    return AppButton(
      text: 'Logout',
      width: 110.w,
      backgroundColor: Colors.blue,
      onPressed: logout,
    );
  }

  TextButton groupButton() {
    return TextButton(
      // 그룹 참여
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.grey[300],
        padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 10.0.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
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
    );
  }
}
