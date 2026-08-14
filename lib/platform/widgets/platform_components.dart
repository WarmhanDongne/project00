import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';

enum PlatformButtonStyle { primary, secondary, danger }

enum PlatformNoticeStyle { success, warning, danger }

//=======================공용 패널==============================
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
    final colors = context.platformColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: colors.border) : null,
      ),
      child: child,
    );
  }
}

//=======================공용 버튼==============================
class PlatformButton extends StatelessWidget {
  const PlatformButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PlatformButtonStyle.primary,
    this.height = 48,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PlatformButtonStyle style;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final background = switch (style) {
      PlatformButtonStyle.primary => colors.primary,
      PlatformButtonStyle.secondary => colors.surface,
      PlatformButtonStyle.danger => colors.danger,
    };
    final foreground = style == PlatformButtonStyle.secondary
        ? colors.text
        : Colors.white;
    final button = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: style == PlatformButtonStyle.secondary
                ? BorderSide(color: colors.border)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

//=======================공용 태그==============================
class PlatformTag extends StatelessWidget {
  const PlatformTag({super.key, required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? colors.primarySoft : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? colors.primary : colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

//=======================공용 상태 안내==============================
class PlatformNotice extends StatelessWidget {
  const PlatformNotice({super.key, required this.message, required this.style});

  final String message;
  final PlatformNoticeStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final foreground = switch (style) {
      PlatformNoticeStyle.success => colors.success,
      PlatformNoticeStyle.warning => colors.warning,
      PlatformNoticeStyle.danger => colors.danger,
    };
    final background = switch (style) {
      PlatformNoticeStyle.success => colors.successSoft,
      PlatformNoticeStyle.warning => colors.warningSoft,
      PlatformNoticeStyle.danger => colors.dangerSoft,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

//=======================공용 인증 화면 배경==============================
class PlatformAuthShell extends StatelessWidget {
  const PlatformAuthShell({
    super.key,
    required this.child,
    this.showBack = false,
    this.maxWidth = 420,
  });

  final Widget child;
  final bool showBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (showBack)
              Positioned(
                left: 16,
                top: 16,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: PlatformPanel(
                    border: false,
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                tooltip: '뒤로',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              )
            : null,
        titleSpacing: showBack ? 0 : 20,
        title: Text(title),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.border),
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
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
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
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
