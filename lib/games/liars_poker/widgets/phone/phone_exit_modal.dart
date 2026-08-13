import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰 게임 화면에서 나가기 전 사용자의 선택을 확인하는 퇴장 모달입니다.
///
/// `false`는 게임 계속하기, `true`는 현재 게임 화면에서 나가기를 의미합니다.
class PhoneExitModal extends StatelessWidget {
  const PhoneExitModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (_) => const PhoneExitModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.landscape
              ? _buildLandscape(context)
              : _buildPortrait(context);
        },
      ),
    );
  }

  //==================================세로 화면==================================
  Widget _buildPortrait(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final imageHeight = (screenHeight * 0.34).clamp(180.0, 280.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: _ModalSurface(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.games.liarsPoker.images.modal.modalImageDoor.image(
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                _buildTextContent(),
                const SizedBox(height: 24),
                // 세로 버튼은 모달의 사용 가능한 너비를 모두 사용합니다.
                SizedBox(
                  width: double.infinity,
                  child: _buildContinueButton(context),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildExitButton(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //==================================가로 화면==================================
  Widget _buildLandscape(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final modalWidth = math.min(screenSize.width - 40, 760.0);

    return SizedBox(
      width: modalWidth,
      child: _ModalSurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 왼쪽: 퇴장 이미지
              Expanded(
                flex: 5,
                child: Assets.games.liarsPoker.images.modal.modalImageDoor
                    .image(
                      height: 220,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
              ),
              const SizedBox(width: 28),
              // 오른쪽: 문구 Column 안에 버튼 Row를 배치합니다.
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextContent(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildContinueButton(context)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExitButton(context)),
                      ],
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

  Widget _buildTextContent() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '게임에서 나가시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '게임을 나가면 다시 접속할 수 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFB9C7BE),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  //====================================계속하기 버튼====================================
  Widget _buildContinueButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(false),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF092014),
        elevation: 9,
        shadowColor: const Color(0xB3000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('계속하기'),
    );
  }

  //====================================나가기 버튼====================================
  Widget _buildExitButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: const Color(0xFF092014),
        foregroundColor: Colors.white,
        elevation: 9,
        shadowColor: const Color(0xB3000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('나가기'),
    );
  }
}

/// 가로·세로에서 동일한 모달 배경과 그림자를 사용합니다.
class _ModalSurface extends StatelessWidget {
  const _ModalSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF142119),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xC0000000),
            blurRadius: 34,
            spreadRadius: 2,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}
