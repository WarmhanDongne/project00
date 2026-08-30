import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';

enum PlatformButtonStyle { primary, secondary, neutral, danger, dangerSoft }

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
    this.loading = false,
    this.leading,
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
    final background = switch (style) {
      PlatformButtonStyle.primary => colors.primary,
      PlatformButtonStyle.secondary => colors.surface,
      PlatformButtonStyle.neutral => colors.surfaceMuted,
      PlatformButtonStyle.danger => colors.danger,
      PlatformButtonStyle.dangerSoft => colors.dangerSoft,
    };
    final foreground = switch (style) {
      PlatformButtonStyle.secondary => colors.text,
      PlatformButtonStyle.neutral => colors.textMuted,
      PlatformButtonStyle.dangerSoft => colors.danger,
      _ => Colors.white,
    };
    final button = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            // dangerSoft는 옅은 배경만으로는 면이 흐려 보여
            // danger를 옅게 깐 테두리로 윤곽을 잡습니다.
            side: switch (style) {
              PlatformButtonStyle.secondary => BorderSide(color: colors.border),
              PlatformButtonStyle.dangerSoft => BorderSide(
                color: colors.danger.withValues(alpha: 0.3),
              ),
              _ => BorderSide.none,
            },
          ),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : leading == null
            ? Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading!,
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? colors.primarySoft : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? colors.primary : colors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
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
          leading ??
              Icon(
                switch (style) {
                  PlatformNoticeStyle.success => Icons.check_circle_rounded,
                  PlatformNoticeStyle.danger => Icons.error_rounded,
                  PlatformNoticeStyle.warning => Icons.warning_rounded,
                },
                size: 16,
                color: foreground,
              ),
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
    this.onBackPressed,
    this.maxWidth = 420,
  });

  final Widget child;
  final bool showBack;
  final VoidCallback? onBackPressed;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.platformColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 남는 세로 공간이 있으면 가운데에 두고, 내용이 화면보다 길거나
            // 키보드가 올라오면 위에서부터 스크롤합니다.
            LayoutBuilder(
              builder: (context, constraints) {
                // showBack이면 위아래를 같이 띄워 뒤로가기 버튼을 피하면서도
                // 정확히 가운데에 놓입니다.
                final vertical = showBack ? 72.0 : 24.0;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: vertical,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Stack에서 나중에 그려야 스크롤 영역의 투명한 RenderBox가 버튼의
            // hit test를 가로채지 않습니다.
            if (showBack)
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      onBackPressed ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
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
