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
    required this.profileImageBytes,
    required this.onPickProfileImage,
    required this.onCheckNickname,
    required this.onSendPhoneCode,
    required this.onConfirmPhoneCode,
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
  final VoidCallback onSendPhoneCode;
  final VoidCallback onConfirmPhoneCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onPickProfileImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: profileImageBytes == null
                ? null
                : MemoryImage(profileImageBytes!),
            child: profileImageBytes == null
                ? const Text('프로필\n사진', textAlign: TextAlign.center)
                : null,
          ),
        ),
        const SizedBox(height: 30),
        // _InputWithButton(
        //   controller: nicknameController,
        //   hintText: 'NICKNAME:',
        //   buttonText: '사용가능',
        //   onPressed: isLoading ? null : onCheckNickname,
        // ),
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

        const SizedBox(height: 16),
        _InputWithButton(
          controller: phoneController,
          hintText: 'TEL:',
          keyboardType: TextInputType.phone,
          buttonText: isCodeSent ? '재전송' : '인증하기',
          onPressed: isLoading || isPhoneVerified ? null : onSendPhoneCode,
        ),
        if (isCodeSent) ...[
          const SizedBox(height: 16),
          _InputWithButton(
            controller: verificationCodeController,
            hintText: 'VERIFICATION CODE:',
            keyboardType: TextInputType.number,
            buttonText: isPhoneVerified ? '인증완료' : '확인',
            onPressed: isLoading || isPhoneVerified ? null : onConfirmPhoneCode,
          ),
        ],
      ],
    );
  }
}

class _InputWithButton extends StatelessWidget {
  const _InputWithButton({
    required this.controller,
    required this.hintText,
    required this.buttonText,
    required this.onPressed,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final String buttonText;
  final VoidCallback? onPressed;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: const Color(0xFFD4D4D4),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ),
      ],
    );
  }
}
