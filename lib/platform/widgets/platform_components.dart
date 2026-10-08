import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//================================================================
//public components
//=================================================================
// 수정 사항: 각 파트 마다 나뉜 컴포넌트를 독립된 컴포넌트로 나누는 것 고려할 것.
enum PlatformButtonStyle { primary, secondary, neutral, danger, dangerSoft }

enum PlatformNoticeStyle { success, warning, danger }

//=======================공용 패널==============================
/// 시안의 흰 카드입니다. [border]가 켜지면 굵은 검은 테두리와 오프셋 그림자를 씁니다.
class PlatformPanel extends StatelessWidget {
  const PlatformPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return MosiBox(
      padding: padding,
      radius: radius,
      borderWidth: border ? 3 : 0,
      shadowOffset: border ? 6 : 0,
      child: child,
    );
  }
}

//=======================공용 버튼==============================
/*
1. 기본 디자인 제공
2. 버튼 클릭 시 로딩 제공
3. 
 */
class PlatformButton extends StatelessWidget {
  const PlatformButton({
    super.key,
    required this.label, // 버튼 문구
    required this.onPressed, // 클릭 동작
    this.style = PlatformButtonStyle.primary, // 버튼 종류, 스타일은 enum 정의
    this.height = 48,
    this.expand = true,
    this.loading = false, // 로딩 표시 사용 여부
    this.leading, // 버튼 왼쪽에 아이콘 표시
  });

  final String label;
  final VoidCallback? onPressed;
  final PlatformButtonStyle style;
  final double height;
  final bool expand;
  final bool loading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final (variant, background, foreground) = switch (style) {
      PlatformButtonStyle.primary => (
        MosiButtonVariant.filled,
        MosiColors.lime,
        MosiColors.navy,
      ),
      PlatformButtonStyle.secondary => (
        MosiButtonVariant.filled,
        MosiColors.white,
        MosiColors.navy,
      ),
      PlatformButtonStyle.neutral => (
        MosiButtonVariant.outline,
        Colors.transparent,
        colors.textMuted,
      ),
      PlatformButtonStyle.danger => (
        MosiButtonVariant.filled,
        MosiColors.red,
        MosiColors.white,
      ),
      PlatformButtonStyle.dangerSoft => (
        MosiButtonVariant.outline,
        Colors.transparent,
        colors.danger,
      ),
    };
    return MosiButton(
      label: label,
      onPressed: onPressed,
      variant: variant,
      background: background,
      foreground: foreground,
      height: height,
      fontSize: height < 44 ? 14 : 16,
      expand: expand,
      loading: loading,
      leading: leading,
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }
}

//=======================공용 태그==============================
class PlatformTag extends StatelessWidget {
  const PlatformTag({super.key, required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return MosiPill(
      label: label,
      fontSize: 13,
      color: MosiColors.navy,
      background: highlighted ? MosiColors.lime : null,
      borderColor: highlighted ? MosiColors.ink : MosiColors.navy,
    );
  }
}

//=======================공용 상태 안내==============================
class PlatformNotice extends StatelessWidget {
  const PlatformNotice({
    super.key,
    required this.message,
    required this.style,
    this.leading,
  });

  final String message;
  final PlatformNoticeStyle style;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final foreground = switch (style) {
      PlatformNoticeStyle.success => colors.success,
      PlatformNoticeStyle.warning => MosiColors.navy,
      PlatformNoticeStyle.danger => colors.danger,
    };
    final background = switch (style) {
      PlatformNoticeStyle.success => colors.successSoft,
      PlatformNoticeStyle.warning => MosiColors.sun,
      PlatformNoticeStyle.danger => colors.dangerSoft,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: style == PlatformNoticeStyle.warning
              ? MosiColors.ink
              : foreground,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          leading ??
              Icon(
                switch (style) {
                  PlatformNoticeStyle.success => Icons.check_circle_rounded,
                  PlatformNoticeStyle.danger => Icons.error_rounded,
                  PlatformNoticeStyle.warning => Icons.warning_rounded,
                },
                size: 18,
                color: foreground,
              ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: MosiFonts.sans(
                color: foreground,
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//=======================공용 인증 화면 배경==============================
/// 인증 흐름의 바탕입니다. 시안 배치는 [MosiAuthScaffold]가 그립니다.
class PlatformAuthShell extends StatelessWidget {
  const PlatformAuthShell({
    super.key,
    required this.child,
    this.showBack = false,
    this.onBackPressed,
    this.maxWidth = 420,
    this.showTagline = true,
  });

  final Widget child;
  final bool showBack;
  final VoidCallback? onBackPressed;

  /// 예전 배치에서 쓰던 최대 폭입니다. 시안 카드는 폭이 고정이라 쓰지 않습니다.
  final double maxWidth;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return MosiAuthScaffold(
      showTagline: showTagline,
      child: showBack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: MosiIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: '뒤로',
                    onPressed:
                        onBackPressed ?? () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            )
          : child,
    );
  }
}

//=======================모바일 플랫폼 흐름 화면==============================
class PlatformPhoneFlowScaffold extends StatelessWidget {
  const PlatformPhoneFlowScaffold({
    super.key,
    required this.title,
    required this.child,
    this.bottom,
    this.showBack = true,
    this.actions = const [],
    this.onBack,
    this.centerTitle = false,
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final bool showBack;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Scaffold(
      appBar: AppBar(
        centerTitle: centerTitle,
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                tooltip: '뒤로',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              )
            : null,
        titleSpacing: showBack ? 0 : 20,
        title: Text(title),
        actions: actions,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: MosiDashedDivider(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: child,
              ),
            ),
            if (bottom != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.canvas,
                  border: const Border(
                    top: BorderSide(color: MosiColors.navy, width: 2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: bottom,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//=======================플랫폼 섹션 제목==============================
class PlatformSectionTitle extends StatelessWidget {
  const PlatformSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MosiFonts.sans(
              size: 17,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
