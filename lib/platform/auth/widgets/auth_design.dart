import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

//=======================로그인·회원가입 시안 부품==============================
// 시안(로그인 · 회원가입): 태블릿은 왼쪽 보라 그림 + 오른쪽 흰 카드, 휴대폰은
// 보라 머리 + 아래 흰 시트입니다.

/// 화면 짧은 변이 600 이상이면 태블릿 배치를 씁니다.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

/// 인증 화면 바탕입니다. [child]는 흰 카드(태블릿)·흰 시트(휴대폰) 안에 들어갑니다.
class MosiAuthScaffold extends StatelessWidget {
  const MosiAuthScaffold({
    super.key,
    required this.child,
    this.showTagline = true,
  });

  final Widget child;

  /// '모이면 시작하는 게임' 문구를 보일지 정합니다(로그인·가입 완료에서만).
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    // AuthGate 아래에서는 같은 배경·로고·카드를 재사용합니다. 독립 진입점도
    // 동일한 화면을 그릴 수 있도록 바깥 shell이 없을 때만 생성합니다.
    if (context.dependOnInheritedWidgetOfExactType<_AuthShellScope>() != null) {
      return child;
    }
    final card = DefaultTextStyle(
      style: MosiFonts.sans(color: MosiColors.navy),
      child: _AuthShellScope(child: child),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 보라 바탕 위라 상태바 글자를 흰색으로 둡니다.
      value: SystemUiOverlayStyle.light,
      child: _buildBody(context, card),
    );
  }

  Widget _buildBody(BuildContext context, Widget card) {
    if (isTabletLayout(context)) {
      return Scaffold(
        backgroundColor: MosiColors.violet,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showHero = constraints.maxWidth >= 900;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 32,
                ),
                child: Row(
                  children: [
                    if (showHero) ...[
                      const Expanded(child: _TabletHero()),
                      const SizedBox(width: 56),
                    ] else
                      const Spacer(),
                    SizedBox(
                      width: 440,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 12, bottom: 12),
                          child: MosiBox(
                            padding: const EdgeInsets.all(32),
                            radius: 12,
                            shadowOffset: 12,
                            child: card,
                          ),
                        ),
                      ),
                    ),
                    if (!showHero) const Spacer(),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: MosiColors.violet,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, showTagline ? 30 : 20, 24, 24),
              child: Column(
                children: [
                  const MosiLogo(markSize: 46, titleSize: 32),
                  if (showTagline) ...[
                    const SizedBox(height: 8),
                    Text(
                      '모이면 시작하는 게임',
                      style: MosiFonts.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: MosiColors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: MosiColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(
                  top: BorderSide(color: MosiColors.ink, width: 3),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthShellScope extends InheritedWidget {
  const _AuthShellScope({required super.child});

  @override
  bool updateShouldNotify(_AuthShellScope oldWidget) => false;
}

/// route를 추가하지 않고 인증 카드 안의 요소만 짧게 퇴장·등장시킵니다.
class MosiAuthTransition extends StatelessWidget {
  const MosiAuthTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    const duration = Duration(milliseconds: 240);
    return AnimatedSize(
      duration: duration,
      alignment: Alignment.topCenter,
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            // 진입/퇴장 모두 같은 key와 위젯 구조를 유지합니다. 퇴장할 때만
            // wrapper를 추가하면 RegisterScreen이 재생성되어 링크를 재사용합니다.
            for (final child in [...previous, ?current])
              ExcludeFocus(
                key: child.key,
                excluding: child != current,
                child: ExcludeSemantics(
                  excluding: child != current,
                  child: IgnorePointer(
                    ignoring: child != current,
                    child: child,
                  ),
                ),
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// 태블릿 왼쪽: 큰 로고 + 문구 + 테이블 그림(태블릿 한 대를 휴대폰이 둘러쌈).
class _TabletHero extends StatefulWidget {
  const _TabletHero();

  @override
  State<_TabletHero> createState() => _TabletHeroState();
}

class _TabletHeroState extends State<_TabletHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MosiLogo(markSize: 72, titleSize: 52),
        const SizedBox(height: 16),
        Text(
          '모이면 시작하는 게임',
          style: MosiFonts.sans(
            size: 20,
            weight: FontWeight.w600,
            color: MosiColors.white,
          ),
        ),
        const SizedBox(height: 18),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 580,
              height: 500,
              child: AnimatedBuilder(
                animation: _bob,
                builder: (context, _) {
                  double bob(double offset) =>
                      -6 * math.sin((_bob.value + offset) * 2 * math.pi);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(
                        left: 85,
                        top: 120,
                        child: _HeroTablet(),
                      ),
                      Positioned(
                        left: 0,
                        top: 160 + bob(0),
                        child: const _HeroPhone(
                          rotate: -12,
                          color: MosiColors.lime,
                          child: _HeroCard(
                            label: 'A',
                            color: MosiColors.red,
                            rotate: -6,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 236,
                        top: 6 + bob(0.25),
                        child: _HeroPhone(
                          rotate: 6,
                          color: MosiColors.sky,
                          child: _heroChip('CALL', MosiColors.sun, 6),
                        ),
                      ),
                      Positioned(
                        left: 492,
                        top: 176 + bob(0.5),
                        child: const _HeroPhone(
                          rotate: 10,
                          color: MosiColors.sun,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _HeroCard(
                                label: 'Q',
                                color: MosiColors.ink,
                                rotate: -10,
                              ),
                              _HeroCard(
                                label: 'K',
                                color: MosiColors.red,
                                rotate: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 250,
                        top: 356 + bob(0.75),
                        child: _HeroPhone(
                          rotate: -5,
                          color: MosiColors.coral,
                          child: _heroChip('LIAR!', MosiColors.white, 999),
                        ),
                      ),
                      Positioned(
                        left: 120,
                        top: 404,
                        child: Transform.rotate(
                          angle: -12 * math.pi / 180,
                          child: const _HeroDie(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _heroChip(String label, Color color, double radius) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: MosiColors.ink, width: 2),
  ),
  child: Text(label, style: MosiFonts.grotesk(size: 12, color: MosiColors.ink)),
);

class _HeroTablet extends StatelessWidget {
  const _HeroTablet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 270,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MosiColors.ink,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: MosiColors.navy, offset: Offset(10, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: MosiColors.green,
          child: Stack(
            children: [
              Center(
                child: MosiDashedBorder(
                  color: const Color(0x59FFFFFF),
                  radius: 70,
                  strokeWidth: 3,
                  child: const SizedBox(width: 240, height: 140),
                ),
              ),
              Positioned(
                left: 118,
                top: 56,
                child: Transform.rotate(
                  angle: -10 * math.pi / 180,
                  child: Container(
                    width: 52,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MosiColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MosiColors.ink, width: 3),
                    ),
                    child: Text(
                      '7',
                      style: MosiFonts.grotesk(size: 24, color: MosiColors.red),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 164,
                top: 50,
                child: Transform.rotate(
                  angle: 5 * math.pi / 180,
                  child: Container(
                    width: 52,
                    height: 74,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: MosiColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MosiColors.ink, width: 3),
                    ),
                    child: Container(color: MosiColors.sky),
                  ),
                ),
              ),
              Positioned(
                left: 234,
                top: 96,
                child: Transform.rotate(
                  angle: 14 * math.pi / 180,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: MosiColors.sun,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: MosiColors.ink, width: 2.5),
                    ),
                    child: const _Pips(color: MosiColors.ink, diagonal: true),
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

class _HeroPhone extends StatelessWidget {
  const _HeroPhone({
    required this.rotate,
    required this.color,
    required this.child,
  });

  final double rotate;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate * math.pi / 180,
      child: Container(
        width: 76,
        height: 136,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          color: MosiColors.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.color,
    required this.rotate,
  });

  final String label;
  final Color color;
  final double rotate;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate * math.pi / 180,
      child: Container(
        width: 26,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MosiColors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: MosiColors.ink, width: 2),
        ),
        child: Text(label, style: MosiFonts.grotesk(size: 15, color: color)),
      ),
    );
  }
}

class _HeroDie extends StatelessWidget {
  const _HeroDie();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 7,
            child: Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: MosiColors.navy,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          Positioned(
            left: 3,
            top: 3,
            child: Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: MosiColors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: MosiColors.ink, width: 2),
              ),
              child: const _Pips(color: MosiColors.red, diagonal: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  const _Pips({required this.color, required this.diagonal});

  final Color color;
  final bool diagonal;

  @override
  Widget build(BuildContext context) {
    final dots = diagonal
        ? const [
            Alignment(-0.55, -0.55),
            Alignment.center,
            Alignment(0.55, 0.55),
          ]
        : const [
            Alignment(-0.5, -0.5),
            Alignment(0.5, -0.5),
            Alignment(-0.5, 0.5),
            Alignment(0.5, 0.5),
          ];
    return Stack(
      children: [
        for (final alignment in dots)
          Align(
            alignment: alignment,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

//=======================제목 + 단계==============================
/// 회원가입 머리: 뒤로 버튼 + 제목 + 3단계 진행 막대.
class MosiAuthHeader extends StatelessWidget {
  const MosiAuthHeader({
    super.key,
    required this.title,
    this.onBack,
    this.stepIndex,
    this.steps = const ['이메일 인증', '비밀번호', '프로필'],
  });

  final String title;
  final VoidCallback? onBack;

  /// 지금 단계(0부터). null이면 진행 막대를 그리지 않습니다.
  final int? stepIndex;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final titleSize = isTabletLayout(context) ? 30.0 : 26.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              Tooltip(
                message: '뒤로',
                child: Semantics(
                  button: true,
                  label: '뒤로',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MosiColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MosiColors.navy, width: 2),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: MosiColors.navy,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: MosiFonts.sans(
                  size: titleSize,
                  weight: FontWeight.w700,
                  color: MosiColors.navy,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
        if (stepIndex != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (i, label) in steps.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 8,
                        decoration: BoxDecoration(
                          color: i < stepIndex!
                              ? MosiColors.navy
                              : i == stepIndex
                              ? MosiColors.lime
                              : MosiColors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: MosiColors.navy, width: 2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: MosiFonts.sans(
                          size: 12,
                          weight: i == stepIndex
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i <= stepIndex!
                              ? MosiColors.navy
                              : const Color(0xFF8C8AA8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

//=======================입력칸==============================
/// 굵은 라벨 + 시안 입력칸.
class MosiLabeledField extends StatelessWidget {
  const MosiLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              if (hint != null)
                TextSpan(
                  text: ' · $hint',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8C8AA8),
                  ),
                ),
            ],
          ),
          style: MosiFonts.sans(
            size: 13,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

TextStyle mosiFieldTextStyle() =>
    MosiFonts.sans(size: 16, color: MosiColors.navy);

/// 이메일 아이디 + '@도메인' 단추. 단추를 누르면 도메인을 고르거나 직접 입력합니다.
class MosiEmailField extends StatelessWidget {
  const MosiEmailField({
    super.key,
    required this.emailController,
    required this.customDomainController,
    required this.customDomainFocusNode,
    required this.emailDomain,
    required this.isCustomDomain,
    required this.onDomainChanged,
    this.enabled = true,
    this.showDomain = true,
    this.trailing,
  });

  final TextEditingController emailController;
  final TextEditingController customDomainController;
  final FocusNode customDomainFocusNode;
  final String emailDomain;
  final bool isCustomDomain;
  final ValueChanged<String?> onDomainChanged;
  final bool enabled;
  final bool showDomain;
  final Widget? trailing;

  static const _domains = ['gmail.com', 'naver.com', 'daum.net'];

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: emailController,
    builder: (context, value, _) => LayoutBuilder(
      builder: (context, constraints) {
        // 전체 주소를 붙여 넣었다면 실제로 쓰이지 않는 도메인 선택은 숨깁니다.
        final hasDomain = showDomain && !value.text.contains('@');
        final domainWidth = (constraints.maxWidth * .48).clamp(120.0, 180.0);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('email-local-field'),
                  controller: emailController,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textAlignVertical: TextAlignVertical.center,
                  style: mosiFieldTextStyle(),
                  decoration: mosiInputDecoration(hintText: '이메일'),
                ),
              ),
              if (hasDomain) ...[
                const SizedBox(width: 8),
                SizedBox(
                  key: const Key('email-domain-block'),
                  width: domainWidth,
                  child: PopupMenuButton<String>(
                    key: const Key('email-domain-menu'),
                    tooltip: '도메인 목록',
                    enabled: enabled,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 6),
                    constraints: BoxConstraints.tightFor(width: domainWidth),
                    onSelected: onDomainChanged,
                    color: MosiColors.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: MosiColors.navy, width: 2),
                    ),
                    itemBuilder: (context) => [
                      for (final domain in [..._domains, 'custom'])
                        PopupMenuItem(
                          value: domain,
                          child: Text(
                            domain == 'custom' ? '직접 입력' : '@$domain',
                            style: MosiFonts.sans(
                              size: 14,
                              weight:
                                  (isCustomDomain
                                      ? domain == 'custom'
                                      : domain == emailDomain)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: MosiColors.navy,
                            ),
                          ),
                        ),
                    ],
                    child: isCustomDomain
                        ? Builder(
                            builder: (buttonContext) => TextField(
                              key: const Key('email-custom-domain-field'),
                              controller: customDomainController,
                              focusNode: customDomainFocusNode,
                              enabled: enabled,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textAlignVertical: TextAlignVertical.center,
                              style: mosiFieldTextStyle(),
                              decoration:
                                  mosiInputDecoration(
                                    hintText: '직접 입력',
                                    suffix: IconButton(
                                      tooltip: '도메인 목록',
                                      onPressed: enabled
                                          ? () => buttonContext
                                                .findAncestorStateOfType<
                                                  PopupMenuButtonState<String>
                                                >()!
                                                .showButtonMenu()
                                          : null,
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ).copyWith(
                                    prefixText: '@',
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 48,
                                    ),
                                  ),
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: MosiColors.cream,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: enabled
                                    ? MosiColors.navy
                                    : MosiColors.navyFaint,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '@$emailDomain',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MosiFonts.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: enabled
                                          ? MosiColors.navy
                                          : MosiColors.navyDim,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  size: 16,
                                  color: MosiColors.navy,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Center(child: trailing!),
              ],
            ],
          ),
        );
      },
    ),
  );
}

//=======================알림 띠==============================
enum MosiNoticeTone { error, success, info }

class MosiNotice extends StatelessWidget {
  const MosiNotice({
    super.key,
    required this.message,
    this.tone = MosiNoticeTone.error,
    this.leading,
  });

  final String message;
  final MosiNoticeTone tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, icon) = switch (tone) {
      MosiNoticeTone.error => (
        const Color(0xFFFDE7EA),
        MosiColors.red,
        const Color(0xFFA82E40),
        Icons.error_outline_rounded,
      ),
      MosiNoticeTone.success => (
        const Color(0xFFEAF6DA),
        const Color(0xFF4C8A1E),
        const Color(0xFF2F5E10),
        Icons.check_rounded,
      ),
      MosiNoticeTone.info => (
        MosiColors.cream,
        MosiColors.navy,
        MosiColors.navy,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: MosiFonts.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '또는' 구분선.
class MosiOrDivider extends StatelessWidget {
  const MosiOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE4E1EE), thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: MosiFonts.sans(size: 13, color: const Color(0xFF8C8AA8)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE4E1EE), thickness: 2)),
      ],
    );
  }
}

/// 회원가입·프로필 설정을 멈출지 묻습니다. 멈추면 true.
Future<bool?> showMosiLeaveDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showMosiDialog<bool>(
    context: context,
    builder: (dialogContext) => MosiDialogFrame(
      width: 320,
      padding: const EdgeInsets.all(20),
      radius: 10,
      shadowOffset: 6,
      semanticLabel: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: MosiFonts.sans(
              size: 18,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: MosiFonts.sans(
              size: 13,
              color: MosiColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MosiButton(
                  label: '계속하기',
                  height: 46,
                  fontSize: 14,
                  borderWidth: 2,
                  shadowOffset: 0,
                  expand: true,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MosiButton(
                  label: '중단하기',
                  background: MosiColors.white,
                  foreground: const Color(0xFFA82E40),
                  height: 46,
                  fontSize: 14,
                  borderWidth: 2,
                  shadowOffset: 0,
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
