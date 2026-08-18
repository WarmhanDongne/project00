import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//=======================태블릿 프로필 설정 모달==============================
class TabletProfileModal extends StatefulWidget {
  const TabletProfileModal({super.key});

  @override
  State<TabletProfileModal> createState() => _TabletProfileModalState();
}

class _TabletProfileModalState extends State<TabletProfileModal> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nicknameController;

  Uint8List? _previewImage;
  bool _isSavingNickname = false;
  bool _isSavingImage = false;
  bool _didChange = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final user = _user;
    final nickname = user?.displayName?.trim();
    _nicknameController = TextEditingController(
      text: nickname?.isNotEmpty == true
          ? nickname
          : user?.email?.split('@').first ?? '사용자',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _changeProfileImage() async {
    if (_isSavingImage) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _previewImage = bytes;
      _isSavingImage = true;
    });

    try {
      await _authService.uploadProfileImage(
        imageBytes: bytes,
        fileName: image.name,
        contentType: image.mimeType,
      );
      await _authService.createUserDocument();
      _didChange = true;
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  Future<void> _saveNickname() async {
    if (_isSavingNickname) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 2) {
      _showMessage('닉네임을 2자 이상 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSavingNickname = true);
    try {
      await _authService.updateDisplayName(nickname);
      await _authService.createUserDocument();
      _didChange = true;
      if (mounted) _showMessage('닉네임을 변경했습니다.');
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSavingNickname = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _close() => Navigator.of(context).pop(_didChange);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  ImageProvider<Object>? _profileImage() {
    final preview = _previewImage;
    if (preview != null) return MemoryImage(preview);
    final photoUrl = _user?.photoURL;
    return photoUrl?.isNotEmpty == true ? NetworkImage(photoUrl!) : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final image = _profileImage();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: PlatformPanel(
          border: false,
          radius: 16,
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: '닫기',
                    onPressed: _close,
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ),
                CircleAvatar(
                  radius: 58,
                  backgroundColor: colors.surfaceMuted,
                  backgroundImage: image,
                  child: image == null
                      ? Icon(
                          Icons.person_outline,
                          size: 45,
                          color: colors.textMuted,
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 132,
                  child: PlatformButton(
                    label: _isSavingImage ? '변경 중...' : '변경하기',
                    height: 44,
                    style: PlatformButtonStyle.secondary,
                    onPressed: _isSavingImage ? null : _changeProfileImage,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '닉네임',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 88,
                      child: PlatformButton(
                        label: _isSavingNickname ? '저장 중' : '수정',
                        height: 48,
                        style: PlatformButtonStyle.secondary,
                        onPressed: _isSavingNickname ? null : _saveNickname,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PlatformButton(
                  label: '로그아웃',
                  style: PlatformButtonStyle.dangerSoft,
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
