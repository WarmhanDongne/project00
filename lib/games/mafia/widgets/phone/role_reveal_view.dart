import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================P1 역할 카드 확인==============================
/// 아래에 꽂혀 있는 뒷면 카드를 눌러 내 역할을 확인하는 화면입니다.
///
/// 확정 흐름(2026-08 지시): 카드는 **화면 아래(보관 자리)에 뒷면으로** 시작
/// 합니다. 누르면 중앙으로 올라와 뒤집히고, 역할 이름·설명이 나옵니다. 잠시
/// 보여 준 뒤 다시 뒤집혀 제자리(아래)로 돌아갑니다.
///
///   아래(뒷면) → 탭 → 중앙으로 슬라이드 → 뒤집기(확인 처리) → 3초
///   → 다시 뒤집기 → 아래로 슬라이드
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

  /// 재접속 복원용입니다. true면 연출과 힌트 없이 확인이 끝난 상태(카드가
  /// 아래에 꽂힌 모습)로 시작합니다.
  final bool initiallyRevealed;

  /// 카드가 완전히 공개된 시점에 한 번 호출됩니다. 서버에 확인을 알립니다.
  final VoidCallback? onRevealed;

  @override
  State<MafiaRoleRevealView> createState() => _MafiaRoleRevealViewState();
}

class _MafiaRoleRevealViewState extends State<MafiaRoleRevealView>
    with TickerProviderStateMixin {
  //=======================디자인 기준 크기==============================
  // Figma 시안(402 × 874)의 좌표를 비율로 바꿔 어떤 휴대폰에서도 같은 배치가
  // 되도록 합니다. 값을 고칠 때는 시안과 함께 확인하세요.
  static const Size _designSize = Size(402, 874);
  static const double _cardTopRatio = 208 / 874;
  static const double _cardWidthRatio = 286 / 402;
  static const double _cardAspectRatio = 286 / 419.39;
  static const double _roleTextTopRatio = 659 / 874;
  static const double _descriptionTopRatio = 739 / 874;

  /// 힌트 화살표 두 개의 중심 X입니다(시안 187·215).
  static const List<double> _hintCenterXRatios = [187 / 402, 215 / 402];

  /// 힌트 화살표의 세로 위치입니다. 아래에 꽂힌 카드 바로 위에서 카드를
  /// 가리킵니다. ⚠️ 카드가 아래에서 시작하는 시안이 아직 없어 임시 값입니다.
  static const double _hintTopRatio = 718 / 874;

  /// 보관 카드 자리입니다(시안 top 776 — 좌우는 카드와 같음).
  static const double _storedTopRatio = 776 / 874;

  /// 역할을 보여 주는 시간입니다. 이 뒤에 카드가 다시 뒤집혀 내려갑니다.
  static const Duration _viewHold = Duration(seconds: 3);

  /// 슬라이드 값의 의미: 0 = 중앙(공개 자리), 1 = 아래(보관 자리).
  late final AnimationController _slideController;
  late final AnimationController _flipController;
  Timer? _viewTimer;

  /// 카드를 눌러 확인을 시작했는지입니다. 힌트를 숨기고 재탭을 막습니다.
  bool _hasTapped = false;

  /// 확인이 끝나 카드가 아래로 돌아갔거나 돌아가는 중인지입니다.
  bool _isStoring = false;

  /// 역할 이름·설명이 보이는 동안 true입니다(앞면이 완전히 열린 뒤부터).
  bool _showsTexts = false;

  @override
  void initState() {
    super.initState();
    // 카드는 언제나 아래(보관 자리)에서 시작합니다. 재접속 복원이면 그대로
    // 멈춰 있고, 새 판이면 탭을 기다립니다.
    _hasTapped = widget.initiallyRevealed;
    _isStoring = widget.initiallyRevealed;
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    )..addStatusListener(_handleSlideStatus);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 0,
    )..addStatusListener(_handleFlipStatus);
  }

  void _handleSlideStatus(AnimationStatus status) {
    // 중앙에 도착하면 뒤집기 시작. (내려갈 때의 completed는 할 일이 없습니다.)
    if (status == AnimationStatus.dismissed && !_isStoring) {
      _flipController.forward();
    }
  }

  void _handleFlipStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 확정 흐름: 완전히 열린 순간 문구를 보여 주고 확인 처리를 보냅니다.
      // 그 뒤 잠시 보여 주고 카드가 다시 뒤집혀 아래로 돌아갑니다.
      setState(() => _showsTexts = true);
      widget.onRevealed?.call();
      _viewTimer = Timer(_viewHold, () {
        if (!mounted) return;
        setState(() {
          _isStoring = true;
          _showsTexts = false;
        });
        _flipController.reverse();
      });
      return;
    }
    if (status == AnimationStatus.dismissed && _isStoring) {
      // 다시 뒷면이 된 뒤 아래(보관 자리)로 미끄러져 돌아갑니다.
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _slideController
      ..removeStatusListener(_handleSlideStatus)
      ..dispose();
    _flipController
      ..removeStatusListener(_handleFlipStatus)
      ..dispose();
    super.dispose();
  }

  void _reveal() {
    // 역할이 아직 도착하지 않았으면 시작하지 않습니다. 올라온 카드가 빈 이름을
    // 보여 주는 것보다 제자리에 두는 편이 덜 혼란스럽습니다.
    if (_hasTapped || widget.role == null) return;
    setState(() => _hasTapped = true);
    _slideController.reverse();
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
        final revealTop = size.height * _cardTopRatio;
        final storedTop = size.height * _storedTopRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            if (!_hasTapped)
              ..._buildFlipHints(size: size, textScale: textScale),
            // 카드는 보관 자리(시안 top 776)와 공개 자리(시안 top 208) 사이를
            // 오갑니다. 0 = 공개 자리, 1 = 보관 자리.
            AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                final slide = Curves.easeInOut.transform(
                  _slideController.value,
                );
                return Positioned(
                  left: (size.width - cardWidth) / 2,
                  top: revealTop + (storedTop - revealTop) * slide,
                  width: cardWidth,
                  height: cardHeight,
                  child: child!,
                );
              },
              child: _buildCard(cardWidth: cardWidth),
            ),
            // 역할 문구는 앞면이 완전히 열린 동안만 보입니다.
            if (_showsTexts) ..._buildRevealedTexts(size, textScale),
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
      button: !_hasTapped,
      label: _hasTapped ? '내 역할 카드' : '역할 카드 확인하기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _reveal,
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, _) {
            // 시작·끝을 눙치는 곡선으로 종이 카드처럼 부드럽게 돕니다.
            final progress = Curves.easeInOutCubic.transform(
              _flipController.value,
            );
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
  /// 아래에 꽂힌 카드를 가리키는 화살표 두 개입니다. 누르기 전에만 보입니다.
  List<Widget> _buildFlipHints({
    required Size size,
    required double textScale,
  }) {
    final arrowLength = 42 * textScale;
    return [
      for (final centerRatio in _hintCenterXRatios)
        Positioned(
          left: size.width * centerRatio - arrowLength / 2,
          top: size.height * _hintTopRatio,
          width: arrowLength,
          height: arrowLength,
          child: IgnorePointer(
            child: Center(
              child: RotatedBox(
                // 아래(카드)를 향합니다.
                quarterTurns: 1,
                child: Assets.games.mafia.images.other.revealArrow.svg(
                  width: arrowLength,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
    ];
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
