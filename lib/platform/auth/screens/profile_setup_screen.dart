import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.authService,
    this.onboardingService,
    this.imagePicker,
  });

  final FirebaseAuthService? authService;
  final OnboardingService? onboardingService;
  final ImagePicker? imagePicker;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final FirebaseAuthService _authService;
  late final OnboardingService _onboardingService;
  late final ImagePicker _imagePicker;
  final _nicknameController = TextEditingController();
  Uint8List? _profileImageBytes;
  String? _profileImageName;
  String? _profileImageType;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
    _onboardingService = widget.onboardingService ?? OnboardingService();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _nicknameController.text =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    if (_isSaving || _isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _errorMessage = null;
    });
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImageBytes = bytes;
        _profileImageName = image.name;
        _profileImageType = image.mimeType;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.code == 'already_active'
            ? '앨범이 이미 열려 있습니다.'
            : '앨범을 열지 못했습니다. 잠시 후 다시 시도해주세요.';
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _completeProfile() async {
    if (_isSaving || _isPickingImage) return;
    final nickname = _nicknameController.text.trim();
    final length = nickname.runes.length;
    if (length < nicknameMinLength || length > nicknameMaxLength) {
      setState(
        () => _errorMessage =
            '닉네임은 $nicknameMinLength자 이상 $nicknameMaxLength자 이하로 입력해주세요.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      String? profileImageUrl = FirebaseAuth.instance.currentUser?.photoURL;
      if (_profileImageBytes != null) {
        profileImageUrl = await _authService.uploadProfileImage(
          imageBytes: _profileImageBytes!,
          fileName: _profileImageName ?? 'profile.jpg',
          contentType: _profileImageType,
        );
      }
      await _onboardingService.completeProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
      );
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestBack() async {
    if (_isSaving || _isPickingImage) return;
    final shouldLeave = await showMosiLeaveDialog(
      context,
      title: '프로필 설정을 중단할까요?',
      message: '다음에 로그인하면 프로필 설정부터 이어서 할 수 있어요.',
    );
    if (shouldLeave != true) return;
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isPickingImage;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestBack());
      },
      child: MosiAuthScaffold(
        showTagline: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MosiAuthHeader(
              title: '회원가입',
              onBack: () => unawaited(_requestBack()),
              stepIndex: 2,
            ),
            const SizedBox(height: 16),
            RegisterStepTwo(
              nicknameController: _nicknameController,
              isLoading: isBusy,
              googlePhotoURL: FirebaseAuth.instance.currentUser?.photoURL,
              profileImageBytes: _profileImageBytes,
              onPickProfileImage: _pickProfileImage,
              onCheckNickname: _completeProfile,
              onUseAccountPhoto: () => setState(() {
                _profileImageBytes = null;
                _profileImageName = null;
                _profileImageType = null;
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              MosiNotice(message: _errorMessage!),
            ],
            const SizedBox(height: 16),
            MosiButton(
              label: '가입 완료',
              height: 54,
              expand: true,
              loading: _isSaving,
              onPressed: isBusy ? null : _completeProfile,
            ),
          ],
        ),
      ),
    );
  }
}
