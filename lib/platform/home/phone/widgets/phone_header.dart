import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

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
    final colors = context.platformColors;
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL;
    final hasPhoto = photoURL != null && photoURL.isNotEmpty;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            '모시겜',
            style: TextStyle(
              color: colors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 108,
            child: PlatformButton(
              label: buttonText,
              height: 40,
              expand: false,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: Text(
              '로그아웃',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceMuted,
            backgroundImage: hasPhoto ? NetworkImage(photoURL) : null,
            child: hasPhoto
                ? null
                : Icon(Icons.person_outline, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
