import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/mafia_flip_card.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================내 신분 카드 (휴대폰 전 단계 공용)==============================
/// 내 신분 카드입니다. 셸이 모든 단계 위에 계속 얹어 두는 **한 장**입니다.
///
/// 확정된 동작(2026-08):
///
/// | 상황 | 동작 |
/// |---|---|
/// | 신분을 처음 받을 때 | 카드가 **화면 위에서** 내려와 가운데에 뒷면으로 섭니다. 미세하게 위아래로 떠 있습니다 |
/// | 누르면 | 회전하며 신분이 열리고, **0.3초 뒤** 문구가 부드럽게 떠오릅니다 |
/// | 첫 확인 뒤 | [firstRevealHold](1분) 뒤 다시 뒤집혀 아래로 내려갑니다 |
/// | 그 뒤 아무 단계에서나 | 아래에 있는 카드를 누르면 가운데로 올라와 열리고, [peekHold](10초) 뒤 자동으로 내려갑니다. 10초 안에 한 번 더 누르면 바로 내려갑니다 |
/// | 결과 화면 | 카드가 필요 없어 셸이 이 위젯을 아예 얹지 않습니다 |
///
/// 단계가 바뀌면 열려 있던 카드는 곧바로 내려갑니다. 그러지 않으면 다음 화면
/// (밤 지목·투표 등)을 카드가 덮어 조작을 막습니다.
class MafiaPhoneRoleCardLayer extends StatefulWidget {
  const MafiaPhoneRoleCardLayer({
    super.key,
    required this.role,
    required this.phaseKey,
    this.isFirstReveal = false,
    this.entranceDelay = Duration.zero,
    this.notice,
    this.onRevealed,
  });

  /// 내 신분입니다. 아직 못 받았으면(null) 눌러도 열리지 않습니다.
  final MafiaRole? role;

  /// 지금 단계를 가리키는 값입니다. 바뀌면 열린 카드를 내립니다.
  final String phaseKey;

  /// 신분을 처음 확인하는 중인지입니다(P1).
  ///
  /// true면 카드가 화면 위에서 내려오고, 열어 둔 채 1분을 머무릅니다.
  /// 재접속처럼 이미 확인을 마친 상태에서는 false를 주어, 아래에 놓인
  /// 카드를 눌러 다시 보는 평소 동작으로 시작합니다.
  final bool isFirstReveal;

  /// 카드가 내려오기 시작할 때까지 기다리는 시간입니다([isFirstReveal] 전용).
  ///
  /// 확정(2026-08): 태블릿의 **분배 연출이 끝난 뒤에** 카드가 들어옵니다.
  /// 태블릿에서 카드가 아직 날아가는 중인데 휴대폰에 이미 카드가 있으면 카드를
  /// 건네받는 느낌이 사라집니다. 그동안 카드는 아무것도 그리지 않습니다.
  ///
  /// 화면(`phone_game_screen.dart`)이 서버 마감 시각으로 계산해 넘겨 줍니다.
  /// 재접속처럼 이미 지난 경우에는 0이 와서 곧바로 들어옵니다.
  final Duration entranceDelay;

  /// 신분 설명 아래에 한 줄 더 붙이는 **그 사람만의 안내**입니다.
  ///
  /// 카탈로그의 [MafiaRole.description]은 역할마다 고정된 문구지만, 이 값은
  /// 게임마다 달라집니다. 처형자의 목표(`목표 · 홍길동`)와 지난밤에 신분이
  /// 바뀌었다는 알림(도둑·전향)이 여기로 옵니다.
  ///
  /// 한 줄로 들어갑니다. 넘치면 줄어듭니다.
  final String? notice;

  /// 처음 확인이 끝난 시점에 한 번 호출됩니다. 서버에 확인을 알립니다.
  final VoidCallback? onRevealed;

  /// 처음 확인한 신분을 열어 두는 시간입니다.
  static const Duration firstRevealHold = Duration(seconds: 60);

  /// 나중에 다시 열어 볼 때 열어 두는 시간입니다.
  static const Duration peekHold = Duration(seconds: 10);

  /// 카드가 열린 뒤 문구가 떠오르기까지의 시간입니다.
  static const Duration textDelay = Duration(milliseconds: 300);

  /// 카드가 자리를 옮기는 시간입니다.
  static const Duration travelDuration = Duration(milliseconds: 560);

  /// 카드가 뒤집히는 시간입니다.
  static const Duration flipDuration = Duration(milliseconds: 620);

  @override
  State<MafiaPhoneRoleCardLayer> createState() =>
      _MafiaPhoneRoleCardLayerState();
}

/// 카드가 지금 무엇을 하고 있는지입니다.
enum _CardStage {
  /// 아직 오지 않았습니다. 태블릿에서 분배 연출이 도는 중입니다.
  ///
  /// 이 동안에는 아무것도 그리지 않습니다(아래에 놓인 카드조차 없습니다).
  undelivered,

  /// 화면 위에서 내려오는 중입니다(처음 확인 전용).
  entering,

  /// 가운데에서 뒷면으로 떠 있습니다. 누르면 열립니다.
  waiting,

  /// 뒤집히는 중입니다.
  flipping,

  /// 열려 있습니다. 시간이 지나거나 누르면 내려갑니다.
  revealed,

  /// 되돌아 뒤집히거나 내려가는 중입니다.
  returning,

  /// 화면 아래에 놓여 있습니다. 누르면 다시 열립니다.
  stored,
}

class _MafiaPhoneRoleCardLayerState extends State<MafiaPhoneRoleCardLayer>
    with TickerProviderStateMixin {
  //=======================시안 기준 좌표==============================
  /// 열렸을 때 카드 자리입니다(시안 P1).
  static const double _centerTop = 208;

  /// 평소 카드 자리입니다.
  static const double _storedTop = MafiaPhoneDesign.storedCardTop;

  /// 신분 문구 자리입니다(시안 P1).
  static const double _roleTextTop = 659;
  static const double _descriptionTop = 739;

  /// 개인 안내([MafiaPhoneRoleCardLayer.notice]) 자리입니다.
  ///
  /// 설명(최대 3줄)이 끝나는 아래이자 화면 바닥(874) 위입니다. 한 줄만
  /// 들어가므로 여기서 더 내려가지 않습니다.
  static const double _noticeTop = 812;

  /// 누르라는 화살표 자리입니다(시안 P1 — 카드 위·아래에서 카드를 가리킵니다).
  static const double _hintAboveTop = 144;
  static const double _hintBelowTop = 651;
  static const List<double> _hintCenterX = [187, 215];

  /// 가운데에서 떠 있을 때 위아래로 흔들리는 폭입니다.
  static const double _bobAmplitude = 5;

  late final AnimationController _travel;
  late final AnimationController _flip;
  late final AnimationController _text;
  late final AnimationController _bob;

  Timer? _holdTimer;
  Timer? _textTimer;
  Timer? _entranceTimer;

  _CardStage _stage = _CardStage.stored;

  /// 카드가 움직이는 두 자리입니다(시안 좌표).
  double _originTop = _storedTop;
  double _targetTop = _storedTop;

  /// 이번에 열어 둘 시간입니다. 첫 확인이면 1분, 그 뒤로는 10초입니다.
  Duration _hold = MafiaPhoneRoleCardLayer.peekHold;

  /// 처음 확인을 이미 알렸는지입니다. 확인은 한 번만 보냅니다.
  bool _hasReportedReveal = false;

  @override
  void initState() {
    super.initState();
    _travel = AnimationController(
      vsync: this,
      duration: MafiaPhoneRoleCardLayer.travelDuration,
      value: 1,
    )..addStatusListener(_handleTravelDone);
    _flip = AnimationController(
      vsync: this,
      duration: MafiaPhoneRoleCardLayer.flipDuration,
    )..addStatusListener(_handleFlipDone);
    _text = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // 가운데에서 기다리는 동안 아주 조금 떠 있게 만듭니다.
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    if (!widget.isFirstReveal) return;
    if (widget.entranceDelay <= Duration.zero) {
      _startEntrance();
      return;
    }
    // 태블릿에서 카드가 다 날아갈 때까지 기다립니다.
    _stage = _CardStage.undelivered;
    _entranceTimer = Timer(widget.entranceDelay, () {
      if (!mounted) return;
      setState(_startEntrance);
    });
  }

  /// 화면 위에서 카드가 내려옵니다(처음 확인).
  void _startEntrance() {
    _stage = _CardStage.entering;
    _hold = MafiaPhoneRoleCardLayer.firstRevealHold;
    // 카드 높이만큼 위로 올려 화면 밖에서 시작합니다.
    _originTop = -MafiaPhoneDesign.storedCardTop;
    _targetTop = _centerTop;
    _travel.forward(from: 0);
  }

  void _handleTravelDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_stage == _CardStage.entering) {
      // 가운데에 도착했습니다. 누를 때까지 떠 있습니다.
      setState(() => _stage = _CardStage.waiting);
      _bob.repeat();
      return;
    }
    if (_stage == _CardStage.returning) {
      setState(() => _stage = _CardStage.stored);
    }
  }

  void _handleFlipDone(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      // 열렸습니다. 0.3초 뒤에 문구가 떠오릅니다.
      setState(() => _stage = _CardStage.revealed);
      if (!_hasReportedReveal) {
        _hasReportedReveal = true;
        widget.onRevealed?.call();
      }
      _textTimer = Timer(MafiaPhoneRoleCardLayer.textDelay, () {
        if (mounted) _text.forward();
      });
      _holdTimer = Timer(_hold, _close);
      return;
    }
    if (status == AnimationStatus.dismissed && _stage == _CardStage.returning) {
      // 다시 뒷면이 됐습니다. 이제 아래로 내려갑니다.
      _originTop = _centerTop;
      _targetTop = _storedTop;
      _travel.forward(from: 0);
    }
  }

  /// 카드를 엽니다. 아래에 있던 카드는 가운데로 올라온 뒤 뒤집힙니다.
  void _open() {
    if (widget.role == null) return;
    _holdTimer?.cancel();
    _bob.stop();
    _hold = MafiaPhoneRoleCardLayer.peekHold;
    setState(() => _stage = _CardStage.flipping);
    _originTop = _storedTop;
    _targetTop = _centerTop;
    // 올라오면서 곧바로 뒤집힙니다(누름 한 번으로 끝납니다).
    _travel.forward(from: 0);
    _flip.forward(from: 0);
  }

  /// 열린 카드를 닫습니다. 되돌아 뒤집힌 뒤 아래로 내려갑니다.
  void _close() {
    if (!mounted || _stage == _CardStage.returning) return;
    _holdTimer?.cancel();
    _textTimer?.cancel();
    _bob.stop();
    setState(() => _stage = _CardStage.returning);
    _text.reverse();
    _flip.reverse();
  }

  /// 카드를 눌렀을 때입니다. 상황에 따라 열거나 닫습니다.
  void _handleCardTap() {
    switch (_stage) {
      case _CardStage.stored:
        _open();
      case _CardStage.waiting:
        // 처음 확인: 뒷면을 눌러 신분을 엽니다.
        _holdTimer?.cancel();
        _bob.stop();
        setState(() => _stage = _CardStage.flipping);
        _flip.forward(from: 0);
      case _CardStage.revealed:
        // 다 봤으면 기다리지 않고 바로 내려갑니다.
        _close();
      // 아직 오지 않은 카드는 화면에 없어 눌릴 일도 없습니다.
      case _CardStage.undelivered:
      case _CardStage.entering:
      case _CardStage.flipping:
      case _CardStage.returning:
        break;
    }
  }

  @override
  void didUpdateWidget(MafiaPhoneRoleCardLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 단계가 바뀌면 열린 카드는 다음 화면을 가리지 않게 내려갑니다.
    if (oldWidget.phaseKey != widget.phaseKey && _isOpen) {
      _close();
    }
    // 새 판이 시작돼 신분을 다시 받는 경우입니다.
    if (!oldWidget.isFirstReveal && widget.isFirstReveal) {
      _hasReportedReveal = false;
      _flip.value = 0;
      _text.value = 0;
      _startEntrance();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _textTimer?.cancel();
    _entranceTimer?.cancel();
    _travel
      ..removeStatusListener(_handleTravelDone)
      ..dispose();
    _flip
      ..removeStatusListener(_handleFlipDone)
      ..dispose();
    _text.dispose();
    _bob.dispose();
    super.dispose();
  }

  /// 카드가 가운데에 나와 있는지입니다.
  bool get _isOpen =>
      _stage == _CardStage.entering ||
      _stage == _CardStage.waiting ||
      _stage == _CardStage.flipping ||
      _stage == _CardStage.revealed;

  /// 어두운 막을 깔지입니다.
  ///
  /// 처음 확인(P1)은 시안이 밝은 배경에 검은 글씨라 막을 깔지 않습니다.
  /// 그 뒤 다른 단계에서 열어 볼 때는 막을 깔아, 뒤 화면의 잘못 눌림을 막고
  /// 밤 화면에서도 문구가 읽히게 합니다.
  bool get _usesScrim => !widget.isFirstReveal;

  @override
  Widget build(BuildContext context) {
    // 태블릿에서 카드가 아직 날아오는 중입니다. 화면에는 아무것도 없습니다.
    if (_stage == _CardStage.undelivered) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final cardWidth = MafiaPhoneDesign.contentWidth * scale;
        final cardHeight = cardWidth / MafiaPhoneDesign.storedCardAspectRatio;

        return AnimatedBuilder(
          animation: Listenable.merge([_travel, _flip, _bob]),
          builder: (context, _) {
            final travel = Curves.easeInOut.transform(_travel.value);
            final designTop = _originTop + (_targetTop - _originTop) * travel;
            // 기다리는 동안만 아주 조금 떠 있습니다.
            final bob = _stage == _CardStage.waiting
                ? math.sin(_bob.value * math.pi * 2) * _bobAmplitude * scale
                : 0.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (_usesScrim) _buildScrim(),
                if (widget.isFirstReveal && _stage == _CardStage.waiting)
                  ..._buildHints(size, scale),
                Positioned(
                  left: MafiaPhoneDesign.left(
                    size,
                    MafiaPhoneDesign.contentLeft,
                  ),
                  top: MafiaPhoneDesign.top(size, designTop) + bob,
                  width: cardWidth,
                  height: cardHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleCardTap,
                    child: Semantics(
                      button: true,
                      label: _isOpen ? '내 신분 카드' : '내 신분 확인하기',
                      child: MafiaFlipCard(
                        progress: Curves.easeInOutCubic.transform(_flip.value),
                        front: widget.role?.card,
                        back: Assets.games.mafia.images.cards.roleBack.game,
                        borderRadius: BorderRadius.circular(
                          MafiaPhoneDesign.buttonRadius * scale,
                        ),
                      ),
                    ),
                  ),
                ),
                ..._buildTexts(size, scale),
              ],
            );
          },
        );
      },
    );
  }

  /// 카드 뒤를 덮는 막입니다. 눌러도 카드가 닫힙니다.
  Widget _buildScrim() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_isOpen,
        child: AnimatedOpacity(
          opacity: _isOpen ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const ColoredBox(color: Color(0x8C000000)),
          ),
        ),
      ),
    );
  }

  //=======================누르라는 화살표==============================
  /// 카드 위·아래에서 카드를 가리킵니다. 처음 확인 때만 보입니다.
  List<Widget> _buildHints(Size size, double scale) {
    final length = 42 * scale;
    return [
      for (final isAbove in [true, false])
        for (final centerX in _hintCenterX)
          Positioned(
            left: MafiaPhoneDesign.left(size, centerX) - length / 2,
            top: MafiaPhoneDesign.top(
              size,
              isAbove ? _hintAboveTop : _hintBelowTop,
            ),
            width: length,
            height: length,
            child: IgnorePointer(
              child: Center(
                child: RotatedBox(
                  // 위쪽 화살표는 아래(카드)를, 아래쪽 화살표는 위를 향합니다.
                  quarterTurns: isAbove ? 1 : 3,
                  child: Assets.games.mafia.images.other.revealArrow.svg(
                    width: length,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
    ];
  }

  //=======================신분 문구==============================
  /// 카드가 열린 뒤 0.3초 뒤에 떠오릅니다.
  List<Widget> _buildTexts(Size size, double scale) {
    final role = widget.role;
    if (role == null) return const [];
    // 열려 있는 동안(그리고 닫히며 사라지는 동안)만 트리에 둡니다. 카드가
    // 아래에 있을 때 투명한 문구가 남아 있으면 화면 낭독기에도 읽힙니다.
    if (_stage != _CardStage.revealed && _stage != _CardStage.returning) {
      return const [];
    }
    // 막을 깐 경우에는 흰 글씨가 읽힙니다.
    final baseColor = _usesScrim ? Colors.white : Colors.black;

    return [
      _buildFadingText(
        size: size,
        designTop: _roleTextTop,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '당신은 ', style: _bodyStyle(scale, baseColor)),
              TextSpan(
                text: role.displayName,
                style: _bodyStyle(
                  scale,
                  baseColor,
                ).copyWith(fontSize: 32 * scale, color: role.accentColor),
              ),
              TextSpan(text: '입니다', style: _bodyStyle(scale, baseColor)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
      if (role.description.trim().isNotEmpty)
        _buildFadingText(
          size: size,
          designTop: _descriptionTop,
          child: Text(
            role.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: baseColor,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w300,
              height: 1.35,
            ),
          ),
        ),
      // 그 사람만의 안내(처형자의 목표, 신분이 바뀌었다는 알림)입니다.
      if ((widget.notice ?? '').trim().isNotEmpty)
        _buildFadingText(
          size: size,
          designTop: _noticeTop,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.notice!,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: role.accentColor,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildFadingText({
    required Size size,
    required double designTop,
    required Widget child,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      top: MafiaPhoneDesign.top(size, designTop),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _text,
          builder: (context, inner) {
            final eased = Curves.easeOut.transform(_text.value);
            return Opacity(
              opacity: eased,
              // 아래에서 살짝 올라오며 떠오릅니다.
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - eased)),
                child: inner,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }

  TextStyle _bodyStyle(double scale, Color color) => TextStyle(
    color: color,
    fontSize: 24 * scale,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
