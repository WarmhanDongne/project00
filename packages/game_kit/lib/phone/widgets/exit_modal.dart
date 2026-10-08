// [exit_modal.dart] 는 휴대폰 게임 화면의 퇴장 확인 UI를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';

// ============================================================

/// 공용 휴대폰 퇴장 모달입니다(시안: 크림 판 위 동그란 얼굴 + '정말 갈 거예요?').
///
/// [characterId]를 주면 내 포커페이스 얼굴을, 없으면 게임이 넘긴 [doorImage]를
/// 동그라미 안에 그립니다. 색 인자는 예전 호출과의 호환을 위해 받기만 합니다.
class SharedPhoneExitModal extends StatelessWidget {
  const SharedPhoneExitModal({
    super.key,
    required this.doorImage,
    this.characterId,
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
  final String? characterId;
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
    String? characterId,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    return showPhoneRippleDialog<bool>(
      context: context,
      origin: origin ?? Offset(screenSize.width - 28, 28),
      builder: (_) => SharedPhoneExitModal(
        doorImage: doorImage,
        characterId: characterId,
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
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
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

  Widget _avatar(double size) {
    final inner = size * 0.82;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MosiColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: MosiColors.ink, width: 3),
      ),
      child: characterId != null
          ? MosiFace(characterId: characterId, size: inner)
          : ClipOval(
              child: SizedBox(width: inner, height: inner, child: doorImage),
            ),
    );
  }

  Widget _bubble() => Transform.rotate(
    angle: 6 * math.pi / 180,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MosiColors.white,
        border: Border.all(color: MosiColors.ink, width: 2.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(2),
        ),
      ),
      child: Text(
        '정말 갈 거예요?',
        style: MosiFonts.sans(
          size: 13,
          weight: FontWeight.w700,
          color: MosiColors.ink,
        ),
      ),
    ),
  );

  BoxDecoration get _surface => BoxDecoration(
    color: MosiColors.cream,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: MosiColors.ink, width: 3),
    boxShadow: const [BoxShadow(color: MosiColors.ink, offset: Offset(0, 8))],
  );

  //=======================세로 화면==============================
  Widget _buildPortrait(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(maxWidth, 350)),
      child: Padding(
        padding: const EdgeInsets.only(top: 58),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              decoration: _surface,
              padding: const EdgeInsets.fromLTRB(22, 70, 22, 22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showText) _buildTextContent(),
                    const SizedBox(height: 18),
                    const _ExitWarning(),
                    const SizedBox(height: 20),
                    _buildButtons(context),
                  ],
                ),
              ),
            ),
            Positioned(top: -58, child: _avatar(116)),
            Positioned(
              top: -48,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(100, 0),
                  child: _bubble(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //=======================가로 화면==============================
  Widget _buildLandscape(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final modalWidth = math.min(screenSize.width - 40, 680.0);

    return Container(
      width: modalWidth,
      decoration: _surface,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 200,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0x40111111), width: 2),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _avatar(126),
                  Positioned(left: 92, top: 24, child: _bubble()),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showText) _buildTextContent(align: TextAlign.left),
                    const SizedBox(height: 10),
                    const _ExitWarning(),
                    const SizedBox(height: 14),
                    _buildButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent({TextAlign align = TextAlign.center}) {
    final crossAxis = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxis,
      children: [
        Text(
          '게임과 그룹에서 나갈까요?',
          textAlign: align,
          style: MosiFonts.sans(
            color: MosiColors.navy,
            size: 22,
            weight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '지금 나가면 이번 게임은 종료되고\n그룹에서도 빠져요.',
          textAlign: align,
          style: MosiFonts.sans(
            color: MosiColors.muted,
            size: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 10,
          child: MosiButton(
            label: '나가기',
            background: MosiColors.white,
            foreground: MosiColors.ink,
            borderWidth: 2,
            shadowOffset: 0,
            height: 56,
            radius: 14,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 14,
          child: MosiButton(
            label: '더 놀래요',
            background: MosiColors.lime,
            foreground: MosiColors.ink,
            shadowColor: MosiColors.ink,
            height: 56,
            fontSize: 17,
            radius: 14,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}

class _ExitWarning extends StatelessWidget {
  const _ExitWarning();

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC2283C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MosiColors.ink, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '나가면 이 게임에 다시 들어올 수 없어요.\n'),
                  TextSpan(
                    text: '그룹에 다시 들어오려면 방 코드를 입력해야 해요.',
                    style: MosiFonts.sans(
                      size: 13,
                      weight: FontWeight.w400,
                      color: red.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              style: MosiFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: red,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
