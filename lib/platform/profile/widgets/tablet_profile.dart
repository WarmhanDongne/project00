import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/profile/widgets/tablet_profile_modal.dart';

/// 선반 오른쪽 위 내 프로필 버튼입니다: 닉네임 + 동그란 얼굴.
class Profile extends StatelessWidget {
  const Profile({super.key, this.foreground = MosiColors.navy});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = profileDisplayName(user);
        void openProfile() => showMosiDialog<bool>(
          context: context,
          builder: (_) => const TabletProfileModal(),
        );
        return Semantics(
          button: true,
          label: context.l10n.editProfile,
          onTap: openProfile,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: openProfile,
            child: Container(
              height: 48,
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: foreground, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          locale: Localizations.maybeLocaleOf(context),
                          size: 15,
                          weight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ProfileAvatar(user: user, size: 34),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 계정 닉네임입니다. 없으면 이메일 앞부분을 씁니다.
String profileDisplayName(User? user) {
  final nickname = user?.displayName?.trim();
  if (nickname != null && nickname.isNotEmpty) return nickname;
  return user?.email?.split('@').first ?? '사용자';
}

/// 프로필 사진이 있으면 사진, 없으면 이니셜을 [color] 원 위에 그립니다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    required this.size,
    this.color = MosiColors.lime,
    this.name,
    this.shadow = false,
    this.image,
    this.placeholder,
  });

  final User? user;
  final double size;
  final Color color;

  /// 계정 사진 대신 보여 줄 그림입니다(예: 막 고른 사진 미리보기).
  final ImageProvider? image;

  /// 사진이 없을 때 이니셜 대신 그릴 위젯입니다.
  final Widget? placeholder;

  /// 이니셜을 만들 이름입니다. null이면 계정 닉네임을 씁니다.
  final String? name;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    final ImageProvider? photo =
        image ??
        (photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null);
    final hasPhoto = photo != null;
    final label = (name ?? profileDisplayName(user)).trim();
    final initial = label.isEmpty
        ? '?'
        : String.fromCharCode(label.runes.first);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: MosiColors.ink, width: size > 60 ? 3 : 2.5),
        boxShadow: shadow
            ? const [BoxShadow(color: MosiColors.navy, offset: Offset(5, 5))]
            : null,
        image: hasPhoto
            ? DecorationImage(image: photo, fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : placeholder ??
                Text(
                  initial,
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: size * 0.41,
                    weight: FontWeight.w700,
                    color: MosiColors.ink,
                  ),
                ),
    );
  }
}
