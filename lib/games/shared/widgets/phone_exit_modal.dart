import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';

/// 게임별 이미지와 색상만 주입하는 공용 휴대폰 퇴장 모달입니다.
class SharedPhoneExitModal extends StatelessWidget {
  const SharedPhoneExitModal({
    super.key,
    required this.doorImage,
    required this.surfaceColor,
    required this.primaryColor,
    required this.titleColor,
    required this.descriptionColor,
    this.showSurface = true,
    this.showText = true,
    this.imageHeight,
    this.maxWidth = 380,
  });

  final Widget doorImage;
  final Color surfaceColor;
  final Color primaryColor;
  final Color titleColor;
  final Color descriptionColor;
  final bool showSurface;
  final bool showText;

  /// 그림 자리의 높이입니다. 큰 삽화 대신 작은 표시를 쓰는 게임은 이 값을
  /// 줄여 모달이 화면을 가득 채우지 않게 합니다. null이면 삽화 기준 높이.
  final double? imageHeight;

  /// 세로 화면에서 모달의 최대 너비입니다.
  final double maxWidth;

  static Future<bool?> show(
    BuildContext context, {
    required Widget doorImage,
    required Color surfaceColor,
    required Color primaryColor,
    required Color titleColor,
    required Color descriptionColor,
    Offset? origin,
    bool showSurface = true,
    bool showText = true,
    double? imageHeight,
    double maxWidth = 380,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    return showPhoneRippleDialog<bool>(
      context: context,
      origin: origin ?? Offset(screenSize.width - 28, 28),
      builder: (_) => SharedPhoneExitModal(
        doorImage: doorImage,
        surfaceColor: surfaceColor,
        primaryColor: primaryColor,
        titleColor: titleColor,
        descriptionColor: descriptionColor,
        showSurface: showSurface,
        showText: showText,
        imageHeight: imageHeight,
        maxWidth: maxWidth,
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
    final height = imageHeight ?? (screenHeight * 0.34).clamp(180.0, 280.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _wrapSurface(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: height, child: doorImage),
                const SizedBox(height: 8),
                if (showText) ...[
                  _buildTextContent(),
                  const SizedBox(height: 24),
                ],
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
      child: _wrapSurface(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(height: imageHeight ?? 220, child: doorImage),
              ),
              const SizedBox(width: 28),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showText) ...[
                      _buildTextContent(),
                      const SizedBox(height: 24),
                    ],
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

  Widget _wrapSurface(Widget child) {
    if (!showSurface) return child;
    return _ModalSurface(color: surfaceColor, child: child);
  }

  Widget _buildTextContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '게임과 그룹에서 나갈까요?',
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
          '현재 게임을 종료하고 그룹에서도 나갑니다. 다시 참여하려면 방 코드를 입력해야 합니다.',
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
      child: const Text('계속 참여'),
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
