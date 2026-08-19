import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class RegisterStepTwo extends StatelessWidget {
  const RegisterStepTwo({
    required this.nicknameController,
    required this.isLoading,
    required this.googlePhotoURL,
    required this.profileImageBytes,
    required this.onPickProfileImage,
    required this.onCheckNickname,
    super.key,
  });

  final TextEditingController nicknameController;
  final bool isLoading;
  final Uint8List? profileImageBytes;
  final VoidCallback onPickProfileImage;
  final VoidCallback onCheckNickname;

  final String? googlePhotoURL;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('계정에서 사용할 사진과 닉네임을 정해 주세요.', style: TextStyle(fontSize: 11)),
        const SizedBox(height: 18),
        Row(
          children: [
            GestureDetector(
              onTap: isLoading ? null : onPickProfileImage,
              child: CircleAvatar(
                radius: 38,
                backgroundColor: colors.surfaceMuted,
                backgroundImage: profileImageBytes != null
                    ? MemoryImage(profileImageBytes!)
                    : (googlePhotoURL != null
                          ? NetworkImage(googlePhotoURL!) as ImageProvider
                          : null),
                child: profileImageBytes == null && googlePhotoURL == null
                    ? Text(
                        'photo',
                        style: TextStyle(color: colors.textMuted, fontSize: 9),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 92,
              child: PlatformButton(
                label: '앨범열기',
                style: PlatformButtonStyle.secondary,
                onPressed: isLoading ? null : onPickProfileImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          '닉네임',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nicknameController,
          enabled: !isLoading,
          maxLength: 12,
          onSubmitted: isLoading ? null : (_) => onCheckNickname(),
          decoration: const InputDecoration(hintText: '방장님', counterText: ''),
        ),
      ],
    );
  }
}
