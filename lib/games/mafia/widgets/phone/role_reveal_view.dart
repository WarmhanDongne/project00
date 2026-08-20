import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================P1 역할 카드 확인==============================
/// 뒷면 카드를 눌러 내 역할을 확인하는 화면입니다.
///
/// 역할 이름으로 분기하지 않고 [MafiaRole] 카탈로그의 값(이름·색·설명·카드)만
/// 읽습니다. 그래서 새 신분을 추가해도 이 화면은 수정할 필요가 없습니다.
///
/// 카드 앞면 에셋이 아직 없는 역할([MafiaRole.card]가 null)은 뒷면을 유지하고
/// 이름·설명만 보여줍니다. 에셋이 없다고 화면이 비지 않습니다.
class MafiaRoleRevealView extends StatefulWidget {
  const MafiaRoleRevealView({
    super.key,
    required this.role,
    this.initiallyRevealed = false,
    this.onRevealed,
  });

  /// 내 역할입니다. 아직 배분 전이거나 이 빌드가 모르는 신분이면 null입니다.
  final MafiaRole? role;

  /// 재접속 복원용입니다. true면 뒤집기 연출과 힌트 없이 공개 상태로 시작합니다.
  final bool initiallyRevealed;

  /// 카드가 완전히 공개된 시점에 한 번 호출됩니다. 서버에 확인을 알립니다.
  final VoidCallback? onRevealed;

  @override
  State<MafiaRoleRevealView> createState() => _MafiaRoleRevealViewState();
}

class _MafiaRoleRevealViewState extends State<MafiaRoleRevealView>
    with SingleTickerProviderStateMixin {
  //=======================디자인 기준 크기==============================
  // Figma 시안(402 × 874)의 좌표를 비율로 바꿔 어떤 휴대폰에서도 같은 배치가
  // 되도록 합니다. 값을 고칠 때는 시안과 함께 확인하세요.
  static const Size _designSize = Size(402, 874);
  static const double _cardTopRatio = 208 / 874;
  static const double _cardWidthRatio = 286 / 402;
  static const double _cardAspectRatio = 286 / 419.39;
  static const double _roleTextTopRatio = 659 / 874;
  static const double _descriptionTopRatio = 739 / 874;
  static const double _hintAboveTopRatio = 144 / 874;
  static const double _hintBelowTopRatio = 651 / 874;

  /// 힌트 화살표 두 개의 중심 X입니다(시안 187·215).
  static const List<double> _hintCenterXRatios = [187 / 402, 215 / 402];

  late final AnimationController _flipController;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.initiallyRevealed;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: widget.initiallyRevealed ? 1 : 0,
    )..addStatusListener(_handleFlipStatus);
  }

  void _handleFlipStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    widget.onRevealed?.call();
  }

  @override
  void dispose() {
    _flipController
      ..removeStatusListener(_handleFlipStatus)
      ..dispose();
    super.dispose();
  }

  void _reveal() {
    // 역할이 아직 도착하지 않았으면 뒤집지 않습니다. 뒤집은 뒤에 이름이 비어
    // 보이는 것보다 카드를 그대로 두는 편이 덜 혼란스럽습니다.
    if (_isRevealed || widget.role == null || _flipController.isAnimating) {
      return;
    }
    setState(() => _isRevealed = true);
    _flipController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : _designSize.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : _designSize.height,
        );
        // 글자는 너비 기준으로만 키웁니다. 높이까지 반영하면 가로가 좁은 기기에서
        // 문구가 카드 밖으로 삐져나옵니다.
        final textScale = size.width / _designSize.width;

        final cardWidth = size.width * _cardWidthRatio;
        final cardHeight = cardWidth / _cardAspectRatio;
        final cardTop = size.height * _cardTopRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            if (!_isRevealed)
              ..._buildFlipHints(size: size, textScale: textScale),
            Positioned(
              left: (size.width - cardWidth) / 2,
              top: cardTop,
              width: cardWidth,
              height: cardHeight,
              child: _buildCard(cardWidth: cardWidth),
            ),
            if (_isRevealed) ..._buildRevealedTexts(size, textScale),
          ],
        );
      },
    );
  }

  //=======================카드==============================
  Widget _buildCard({required double cardWidth}) {
    final back = Assets.games.mafia.images.cards.roleBack.game;
    final front = widget.role?.card;

    return Semantics(
      button: !_isRevealed,
      label: _isRevealed ? '내 역할 카드' : '역할 카드 확인하기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _reveal,
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, _) {
            final progress = _flipController.value;
            // 절반을 지나면 앞면으로 바꿔, 뒤집히는 도중에 글자가 거울처럼
            // 반사되어 보이지 않게 합니다.
            final showsFront = progress >= 0.5 && front != null;
            final angle = showsFront
                ? math.pi * (1 - progress)
                : math.pi * progress;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (showsFront ? front : back).image(
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  //=======================뒤집기 힌트 화살표==============================
  /// 카드 위·아래에서 카드를 향하는 화살표입니다. 공개 전에만 보입니다.
  List<Widget> _buildFlipHints({
    required Size size,
    required double textScale,
  }) {
    final arrowLength = 42 * textScale;
    final hints = <Widget>[];

    for (final isAbove in [true, false]) {
      for (final centerRatio in _hintCenterXRatios) {
        hints.add(
          Positioned(
            left: size.width * centerRatio - arrowLength / 2,
            top:
                size.height *
                (isAbove ? _hintAboveTopRatio : _hintBelowTopRatio),
            width: arrowLength,
            height: arrowLength,
            child: IgnorePointer(
              child: Center(
                child: RotatedBox(
                  // 위쪽 화살표는 아래(카드)를, 아래쪽 화살표는 위를 향합니다.
                  quarterTurns: isAbove ? 1 : 3,
                  child: Assets.games.mafia.images.other.revealArrow.svg(
                    width: arrowLength,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return hints;
  }

  //=======================공개 후 문구==============================
  List<Widget> _buildRevealedTexts(Size size, double textScale) {
    final role = widget.role;
    if (role == null) return const [];

    final widgets = <Widget>[
      Positioned(
        left: 0,
        right: 0,
        top: size.height * _roleTextTopRatio,
        child: IgnorePointer(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '당신은 ', style: _bodyStyle(textScale)),
                TextSpan(
                  text: role.displayName,
                  style: _bodyStyle(
                    textScale,
                  ).copyWith(fontSize: 32 * textScale, color: role.accentColor),
                ),
                TextSpan(text: '입니다', style: _bodyStyle(textScale)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];

    // 설명이 없는 역할은 그 영역을 아예 그리지 않습니다.
    if (role.description.trim().isNotEmpty) {
      widgets.add(
        Positioned(
          left: 0,
          right: 0,
          top: size.height * _descriptionTopRatio,
          child: IgnorePointer(
            child: Text(
              role.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 20 * textScale,
                fontWeight: FontWeight.w300,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  TextStyle _bodyStyle(double textScale) => TextStyle(
    color: Colors.black,
    fontSize: 24 * textScale,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
