import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';
import 'package:project00/platform/profile/widgets/tablet_profile_modal.dart';

class PhoneProfile extends StatelessWidget {
  const PhoneProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        void openProfile() => showMosiDialog<bool>(
          context: context,
          builder: (_) => const TabletProfileModal(),
        );
        return Semantics(
          button: true,
          label: context.l10n.openProfile,
          onTap: openProfile,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: openProfile,
            child: ProfileAvatar(user: snapshot.data, size: 40),
          ),
        );
      },
    );
  }
}
