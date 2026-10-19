import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:project00/platform/profile/providers/profile_update_controller.dart';
import 'package:project00/platform/profile/widgets/tablet_profile_modal.dart';

/// 선반 오른쪽 위 내 프로필 버튼입니다: 닉네임 + 동그란 얼굴.
class Profile extends StatelessWidget {
  const Profile({super.key, this.foreground = MosiColors.navy});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final updates = ProfileUpdateController.instance;
    return AnimatedBuilder(
      animation: updates,
      builder: (context, _) => StreamBuilder<User?>(
        stream: FirebaseBackend.auth.userChanges(),
        initialData: FirebaseBackend.auth.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final pending = updates.pendingFor(user?.uid);
          final name = pending?.nickname ?? profileDisplayName(user);
          void openProfile() => showMosiDialog<bool>(
            context: context,
            // 누른 버튼 자리에서 펼쳐지고 같은 자리로 접힙니다(로비 연출 8번).
            origin: mosiOriginOf(context),
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
                    ProfileAvatar(
                      user: user,
                      size: 34,
                      name: name,
                      image: pending?.imageBytes == null
                          ? null
                          : MemoryImage(pending!.imageBytes!),
                      syncing: pending != null && updates.isSaving,
                      syncFailed: pending != null && updates.hasFailed,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 계정 닉네임입니다. 없으면 이메일 앞부분을 씁니다.
String profileDisplayName(User? user) {
  final nickname = user?.displayName?.trim();
  if (nickname != null && nickname.isNotEmpty) return nickname;
  return user?.email?.split('@').first ??
      GameLocale.select(ko: '사용자', en: 'User', zhHans: '用户', zhHant: '使用者');
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
    this.syncing = false,
    this.syncFailed = false,
  });

  final User? user;
  final double size;
  final Color color;

  /// 계정 사진 대신 보여 줄 그림입니다(예: 막 고른 사진 미리보기).
  final ImageProvider? image;

  /// 사진이 없을 때 이니셜 대신 그릴 위젯입니다.
  final Widget? placeholder;
  final bool syncing;
  final bool syncFailed;

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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: MosiColors.ink,
                width: size > 60 ? 3 : 2.5,
              ),
              boxShadow: shadow
                  ? const [
                      BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
                    ]
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
          ),
          if (syncing)
            Positioned.fill(
              key: const Key('profile-syncing-indicator'),
              child: CircularProgressIndicator(
                strokeWidth: size > 50 ? 3 : 2.5,
                color: MosiColors.lime,
                backgroundColor: MosiColors.navy.withValues(alpha: .32),
              ),
            ),
          if (syncFailed)
            Positioned(
              key: const Key('profile-sync-failed-indicator'),
              right: -2,
              bottom: -2,
              child: Container(
                width: size * .34,
                height: size * .34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MosiColors.sun,
                  shape: BoxShape.circle,
                  border: Border.all(color: MosiColors.ink, width: 2),
                ),
                child: Text(
                  '!',
                  style: MosiFonts.sans(
                    size: size * .22,
                    weight: FontWeight.w900,
                    color: MosiColors.ink,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
