import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

/// 회원가입 3단계(프로필): 사진 + 닉네임.
class RegisterStepTwo extends StatelessWidget {
  const RegisterStepTwo({
    required this.nicknameController,
    required this.isLoading,
    required this.googlePhotoURL,
    required this.profileImageBytes,
    required this.onPickProfileImage,
    required this.onCheckNickname,
    this.onUseAccountPhoto,
    super.key,
  });

  final TextEditingController nicknameController;
  final bool isLoading;
  final Uint8List? profileImageBytes;
  final VoidCallback onPickProfileImage;
  final VoidCallback onCheckNickname;

  /// 올린 사진을 지우고 계정(Google) 사진으로 되돌립니다.
  final VoidCallback? onUseAccountPhoto;

  final String? googlePhotoURL;

  @override
  Widget build(BuildContext context) {
    final hasUpload = profileImageBytes != null;
    final hasAccountPhoto =
        googlePhotoURL != null && googlePhotoURL!.isNotEmpty;
    final ImageProvider? image = hasUpload
        ? MemoryImage(profileImageBytes!)
        : hasAccountPhoto
        ? NetworkImage(googlePhotoURL!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GameLocale.select(
            ko: '계정에서 사용할 사진과 닉네임을 정해 주세요.',
            en: 'Choose a profile photo and nickname.',
            zhHans: '请选择账号头像和昵称。',
            zhHant: '請選擇帳號頭像和暱稱。',
          ),
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 14,
            color: MosiColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: MosiColors.cream,
                    shape: BoxShape.circle,
                    border: Border.all(color: MosiColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(color: MosiColors.navy, offset: Offset(4, 4)),
                    ],
                    image: image == null
                        ? null
                        : DecorationImage(image: image, fit: BoxFit.cover),
                  ),
                  child: image == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          size: 52,
                          color: Color(0xFF8C8AA8),
                        )
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Semantics(
                    button: true,
                    label: context.l10n.uploadPhoto,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: isLoading ? null : onPickProfileImage,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: MosiColors.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: MosiColors.ink, width: 3),
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          size: 18,
                          color: MosiColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MosiButton(
                    label: context.l10n.uploadPhoto,
                    variant: MosiButtonVariant.outline,
                    foreground: MosiColors.navy,
                    height: 46,
                    fontSize: 14,
                    expand: true,
                    leading: const Icon(Icons.upload_rounded),
                    onPressed: isLoading ? null : onPickProfileImage,
                  ),
                  if (hasAccountPhoto && onUseAccountPhoto != null) ...[
                    const SizedBox(height: 8),
                    MosiButton(
                      label: context.l10n.useGooglePhoto,
                      variant: hasUpload
                          ? MosiButtonVariant.outline
                          : MosiButtonVariant.filled,
                      background: const Color(0xFFEAF6DA),
                      foreground: MosiColors.navy,
                      borderColor: MosiColors.navy,
                      borderWidth: 2,
                      shadowOffset: 0,
                      height: 46,
                      fontSize: 14,
                      expand: true,
                      onPressed: isLoading || !hasUpload
                          ? null
                          : onUseAccountPhoto,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (hasUpload && onUseAccountPhoto != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: isLoading ? null : onUseAccountPhoto,
              child: Text(
                context.l10n.removePhoto,
                style: MosiFonts.sans(
                  locale: Localizations.maybeLocaleOf(context),
                  size: 13,
                  weight: FontWeight.w700,
                  color: const Color(0xFFA82E40),
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        MosiLabeledField(
          label: context.l10n.nickname,
          hint: GameLocale.select(
            ko: '최대 $nicknameMaxLength자',
            en: 'Up to $nicknameMaxLength characters',
            zhHans: '最多 $nicknameMaxLength 个字符',
            zhHant: '最多 $nicknameMaxLength 個字元',
          ),
          child: TextField(
            controller: nicknameController,
            enabled: !isLoading,
            maxLength: nicknameMaxLength,
            onSubmitted: isLoading ? null : (_) => onCheckNickname(),
            style: mosiFieldTextStyle(),
            decoration: mosiInputDecoration(
              hintText: GameLocale.select(
                ko: '방장님',
                en: 'Host',
                zhHans: '房主',
                zhHant: '房主',
              ),
            ).copyWith(counterText: ''),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          GameLocale.select(
            ko: '사진은 나중에 프로필에서 언제든 바꿀 수 있어요.',
            en: 'You can change your photo anytime in Profile.',
            zhHans: '之后可随时在个人资料中更换头像。',
            zhHant: '之後可隨時在個人資料中更換頭像。',
          ),
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 12,
            color: const Color(0xFF8C8AA8),
          ),
        ),
      ],
    );
  }
}
