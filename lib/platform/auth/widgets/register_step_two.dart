import 'dart:typed_data';
import 'package:flutter/material.dart';

class RegisterStepTwo extends StatelessWidget {
  const RegisterStepTwo({
    required this.nicknameController,
    required this.phoneController,
    required this.verificationCodeController,
    required this.isLoading,
    required this.isCodeSent,
    required this.isPhoneVerified,
    required this.googlePhotoURL,
    required this.profileImageBytes,
    required this.onPickProfileImage,
    required this.onCheckNickname,
    super.key,
  });

  final TextEditingController nicknameController;
  final TextEditingController phoneController;
  final TextEditingController verificationCodeController;
  final bool isLoading;
  final bool isCodeSent;
  final bool isPhoneVerified;
  final Uint8List? profileImageBytes;
  final VoidCallback onPickProfileImage;
  final VoidCallback onCheckNickname;

  final String? googlePhotoURL;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onPickProfileImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: profileImageBytes == null
                ? MemoryImage(profileImageBytes!)
                : (googlePhotoURL != null
                      ? NetworkImage(googlePhotoURL!) as ImageProvider
                      : null),

            child: profileImageBytes == null && googlePhotoURL == null
                ? const Text('프로필\n사진', textAlign: TextAlign.center)
                : null,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nicknameController,
                decoration: InputDecoration(
                  hintText: 'NICKNAME:',
                  filled: true,
                  fillColor: const Color(0xFFD4D4D4),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 100, child: Text('')),
          ],
        ),
      ],
    );
  }
}
