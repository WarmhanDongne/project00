import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/profile/widgets/tablet_profile_modal.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class PhoneProfile extends StatelessWidget {
  const PhoneProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.photoURL;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

        return Semantics(
          button: true,
          label: '내 프로필 열기',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showDialog<bool>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.48),
              builder: (_) => const TabletProfileModal(),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.surfaceMuted,
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Icon(Icons.person_outline, color: colors.textMuted),
            ),
          ),
        );
      },
    );
  }
}
