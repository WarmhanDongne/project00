import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 게임별 이미지와 색상만 주입하는 공용 휴대폰 퇴장 모달입니다.
class SharedPhoneExitModal extends StatelessWidget {
  const SharedPhoneExitModal({
    super.key,
    required this.doorImage,
    required this.surfaceColor,
    required this.primaryColor,
    required this.titleColor,
    required this.descriptionColor,
  });

  final Widget doorImage;
  final Color surfaceColor;
  final Color primaryColor;
  final Color titleColor;
  final Color descriptionColor;

  static Future<bool?> show(
    BuildContext context, {
    required Widget doorImage,
    required Color surfaceColor,
    required Color primaryColor,
    required Color titleColor,
    required Color descriptionColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (_) => SharedPhoneExitModal(
        doorImage: doorImage,
        surfaceColor: surfaceColor,
        primaryColor: primaryColor,
        titleColor: titleColor,
        descriptionColor: descriptionColor,
      ),
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

  //=======================세로 화면==============================
  Widget _buildPortrait(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final imageHeight = (screenHeight * 0.34).clamp(180.0, 280.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: _ModalSurface(
        color: surfaceColor,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: imageHeight, child: doorImage),
                const SizedBox(height: 8),
                _buildTextContent(),
                const SizedBox(height: 24),
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

  //=======================가로 화면==============================
  Widget _buildLandscape(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final modalWidth = math.min(screenSize.width - 40, 760.0);

    return SizedBox(
      width: modalWidth,
      child: _ModalSurface(
        color: surfaceColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: SizedBox(height: 220, child: doorImage)),
              const SizedBox(width: 28),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '게임에서 나가시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: titleColor,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '게임을 나가면 다시 접속할 수 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: descriptionColor, fontSize: 14, height: 1.45),
        ),
      ],
    );
  }

  //=======================계속하기 버튼==============================
  Widget _buildContinueButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(false),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 9,
        shadowColor: const Color(0xB3000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('계속하기'),
    );
  }

  //=======================나가기 버튼==============================
  Widget _buildExitButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 9,
        shadowColor: const Color(0xB3000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('나가기'),
    );
  }
}

class _ModalSurface extends StatelessWidget {
  const _ModalSurface({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
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
