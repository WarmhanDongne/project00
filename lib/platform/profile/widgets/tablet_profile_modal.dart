import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';

//=======================내 프로필 모달==============================
// 시안 '내 프로필'(ProfileModal): 사진 + 이름·이메일, 닉네임, 계정(로그아웃 ·
// 회원탈퇴), 아래 취소/저장. 태블릿과 휴대폰이 같은 모달을 폭만 달리해 씁니다.
class TabletProfileModal extends StatefulWidget {
  const TabletProfileModal({super.key, this.authService});

  /// 테스트에서 계정 서비스를 바꿔 끼울 때 씁니다.
  final FirebaseAuthService? authService;

  @override
  State<TabletProfileModal> createState() => _TabletProfileModalState();
}

class _TabletProfileModalState extends State<TabletProfileModal> {
  late final FirebaseAuthService _authService =
      widget.authService ?? FirebaseAuthService();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nicknameController;

  Uint8List? _pickedImage;
  String? _pickedImageName;
  String? _pickedImageType;
  bool _isSaving = false;

  /// 저장이 끝나 체크를 보여 주는 중입니다(로비 연출 9번).
  bool _saved = false;
  bool _isPickingImage = false;
  bool _isDeletingAccount = false;
  bool _isLoggingOut = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  bool get _isBusy =>
      _isSaving || _isPickingImage || _isDeletingAccount || _isLoggingOut;

  @override
  void initState() {
    super.initState();
    final name = profileDisplayName(_user);
    _nicknameController = TextEditingController(
      text: name.length <= nicknameMaxLength
          ? name
          : name.substring(0, nicknameMaxLength),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isBusy) return;
    setState(() => _isPickingImage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = bytes;
        _pickedImageName = image.name;
        _pickedImageType = image.mimeType;
      });
    } catch (_) {
      if (mounted) _showMessage('앨범을 열지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  /// 바뀐 사진과 닉네임만 저장하고 닫습니다. 바뀐 것이 있으면 true로 닫습니다.
  Future<void> _save() async {
    if (_isBusy) return;
    final nickname = _nicknameController.text.trim();
    final nicknameChanged = nickname != profileDisplayName(_user);
    if (nicknameChanged && nickname.runes.length < nicknameMinLength) {
      _showMessage('닉네임을 $nicknameMinLength자 이상 입력해주세요.');
      return;
    }
    final image = _pickedImage;
    if (!nicknameChanged && image == null) {
      Navigator.of(context).pop(false);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      if (image != null) {
        await _authService.uploadProfileImage(
          imageBytes: image,
          fileName: _pickedImageName ?? 'profile.jpg',
          contentType: _pickedImageType,
        );
      }
      if (nicknameChanged) await _authService.updateDisplayName(nickname);
      await _authService.createUserDocument();
      if (!mounted) return;
      // 버튼 안에 체크를 그려 저장된 것을 보여 준 뒤 닫습니다.
      setState(() {
        _isSaving = false;
        _saved = true;
      });
      await Future<void>.delayed(MosiMotion.of(context, MosiMotion.check));
      if (mounted) Navigator.of(context).pop(true);
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    if (_isBusy) return;
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      // 상점 등에서 연 프로필도 로그인 위에 이전 route를 남기지 않습니다.
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (_) {
      if (mounted) _showMessage('로그아웃하지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isBusy) return;
    if (await _confirmAccountDeletion() != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await _authService.deleteAccount();
      await PlayerRoomSessionStore.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      _showMessage(error.message);
    }
  }

  Future<bool?> _confirmAccountDeletion() {
    return showMosiDialog<bool>(
      context: context,
      builder: (dialogContext) => MosiDialogFrame(
        width: 340,
        padding: const EdgeInsets.all(22),
        radius: 14,
        shadowOffset: 8,
        semanticLabel: context.l10n.deleteAccount,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.deleteAccount,
              style: MosiFonts.sans(
                locale: Localizations.maybeLocaleOf(context),
                size: 20,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '계정과 프로필, 보유 게임 정보가 모두 삭제되며 되돌릴 수 없습니다.\n'
              '정말 탈퇴하시겠습니까?',
              style: MosiFonts.sans(
                locale: Localizations.maybeLocaleOf(context),
                size: 14,
                color: MosiColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: MosiButton(
                    label: context.l10n.cancel,
                    background: MosiColors.white,
                    borderWidth: 2,
                    shadowOffset: 0,
                    height: 48,
                    fontSize: 15,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MosiButton(
                    label: '탈퇴하기',
                    background: const Color(0xFFC2283C),
                    foreground: MosiColors.white,
                    borderWidth: 2,
                    shadowOffset: 0,
                    height: 48,
                    fontSize: 15,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _isGoogleAccount =>
      _user?.providerData.any((info) => info.providerId == 'google.com') ??
      false;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final horizontal = isPhone ? 20.0 : 28.0;
    final avatarSize = isPhone ? 84.0 : 104.0;
    final draftName = _nicknameController.text.trim();
    final email = _user?.email ?? '';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (isPhone ? 358 : 440) + 10,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: MosiDialogFrame(
        width: null,
        padding: EdgeInsets.zero,
        radius: 22,
        shadowOffset: 10,
        semanticLabel: context.l10n.myProfile,
        // 키보드가 올라오거나 화면이 낮아도 저장·회원탈퇴까지 스크롤로 닿도록
        // 판 전체를 한 번에 스크롤합니다.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.l10n.myProfile,
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 26,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const Spacer(),
                        MosiIconButton(
                          icon: Icons.close_rounded,
                          tooltip: context.l10n.close,
                          size: 46,
                          borderWidth: 2.5,
                          color: MosiColors.ink,
                          onPressed: _isBusy
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _AvatarButton(
                          size: avatarSize,
                          user: _user,
                          picked: _pickedImage,
                          busy: _isPickingImage,
                          onTap: _pickImage,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draftName.isEmpty ? ' ' : draftName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MosiFonts.sans(
                                  locale: Localizations.maybeLocaleOf(context),
                                  size: 24,
                                  weight: FontWeight.w700,
                                  color: MosiColors.navy,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (_isGoogleAccount) ...[
                                      const _GoogleBadge(),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MosiFonts.sans(
                                          locale: Localizations.maybeLocaleOf(
                                            context,
                                          ),
                                          size: 13,
                                          color: MosiColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.tapPhoto,
                                style: MosiFonts.sans(
                                  locale: Localizations.maybeLocaleOf(context),
                                  size: 12,
                                  color: const Color(0xFF8C8AA8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          context.l10n.nickname,
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 14,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_nicknameController.text.characters.length}'
                          ' / $nicknameMaxLength',
                          style: MosiFonts.grotesk(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 13,
                            color: const Color(0xFF8C8AA8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nicknameController,
                      enabled: !_isBusy,
                      maxLength: nicknameMaxLength,
                      style: MosiFonts.sans(
                        locale: Localizations.maybeLocaleOf(context),
                        size: 17,
                        color: MosiColors.navy,
                      ),
                      decoration: mosiInputDecoration().copyWith(
                        counterText: '',
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.nicknameHint,
                      style: MosiFonts.sans(
                        locale: Localizations.maybeLocaleOf(context),
                        size: 12,
                        color: MosiColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.account,
                      style: MosiFonts.sans(
                        locale: Localizations.maybeLocaleOf(context),
                        size: 14,
                        weight: FontWeight.w700,
                        color: MosiColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MosiColors.ink, width: 2),
                      ),
                      child: Column(
                        children: [
                          _AccountRow(
                            icon: Icons.logout_rounded,
                            label: context.l10n.logout,
                            color: MosiColors.navy,
                            chevron: const Color(0xFF8C8AA8),
                            onTap: _isBusy ? null : _logout,
                          ),
                          const Divider(
                            height: 1.5,
                            thickness: 1.5,
                            color: Color(0xFFE4E1EE),
                          ),
                          _AccountRow(
                            icon: Icons.delete_outline_rounded,
                            label: _isDeletingAccount
                                ? context.l10n.checkingDeletion
                                : context.l10n.deleteAccount,
                            color: const Color(0xFFC2283C),
                            chevron: const Color(0xFFC9A0A8),
                            onTap: _isBusy ? null : _deleteAccount,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  18,
                  horizontal - 4,
                  20,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: MosiColors.ink, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 10,
                      child: MosiButton(
                        label: context.l10n.cancel,
                        background: MosiColors.white,
                        borderWidth: 2.5,
                        shadowOffset: 0,
                        height: 56,
                        fontSize: 17,
                        radius: 12,
                        expand: true,
                        onPressed: _isBusy
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 13,
                      child: MosiButton(
                        label: context.l10n.save,
                        height: 56,
                        fontSize: 17,
                        radius: 12,
                        expand: true,
                        loading: _isSaving,
                        loadingDots: true,
                        success: _saved,
                        successLabel: context.l10n.profileSaved,
                        onPressed: _isBusy || _saved ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 누르면 앨범을 여는 동그란 사진. 오른쪽 아래 라임 카메라 단추가 붙습니다.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.size,
    required this.user,
    required this.picked,
    required this.busy,
    required this.onTap,
  });

  final double size;
  final User? user;
  final Uint8List? picked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.changePhoto,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 새 사진을 고르면 이전 사진 위로 살짝 작아지며 겹쳐 바뀝니다.
              AnimatedSwitcher(
                duration: MosiMotion.of(
                  context,
                  const Duration(milliseconds: 300),
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.12, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                ),
                child: ProfileAvatar(
                  key: ValueKey(picked == null ? 0 : identityHashCode(picked)),
                  user: user,
                  size: size,
                  color: const Color(0xFFE7E2FF),
                  image: picked == null ? null : MemoryImage(picked!),
                  placeholder: Align(
                    alignment: Alignment.bottomCenter,
                    child: Icon(
                      Icons.person_rounded,
                      size: size * 0.82,
                      color: MosiColors.lilac,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MosiColors.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: MosiColors.ink, width: 2.5),
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MosiColors.ink,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          size: 18,
                          color: MosiColors.ink,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MosiColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9C5DA), width: 1.5),
      ),
      child: Text(
        'G',
        style: MosiFonts.grotesk(
          locale: Localizations.maybeLocaleOf(context),
          size: 11,
          color: const Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.chevron,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: MosiColors.white,
        foregroundColor: color,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: MosiFonts.sans(
                locale: Localizations.maybeLocaleOf(context),
                size: 15,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: chevron),
        ],
      ),
    );
  }
}
