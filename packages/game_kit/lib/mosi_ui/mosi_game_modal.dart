// [mosi_game_modal.dart] 는 게임 안 공용 모달(설정·규칙)의 시안 판을 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 1040×680 흰 판 + 굵은 테두리 + 강조색 오프셋 그림자
//
// 기존 [TabletGameModalFrame]은 게임별 전용 모달도 쓰고 있어 그대로 두고,
// 시안을 입힌 설정·룰북만 이 판을 씁니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

/// 게임 안 모달의 강조색 묶음입니다.
@immutable
class MosiGameModalTheme {
  const MosiGameModalTheme({
    required this.accent,
    required this.accentFg,
    required this.deep,
  });

  final Color accent;
  final Color accentFg;
  final Color deep;

  static const liarsPoker = MosiGameModalTheme(
    accent: Color(0xFFF2C14E),
    accentFg: Color(0xFF1B1022),
    deep: Color(0xFF6E2A82),
  );

  static const finalCall = MosiGameModalTheme(
    accent: Color(0xFFE5DB00),
    accentFg: Color(0xFF141414),
    deep: Color(0xFF141414),
  );

  static const mafia = MosiGameModalTheme(
    accent: Color(0xFFFF4D4D),
    accentFg: MosiColors.white,
    deep: Color(0xFF10131A),
  );

  static const fallback = MosiGameModalTheme(
    accent: MosiColors.lime,
    accentFg: MosiColors.navy,
    deep: MosiColors.violet,
  );

  /// 게임 이름(한글·영문)으로 고릅니다. 모달이 게임 id를 모르기 때문입니다.
  static MosiGameModalTheme fromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.contains('liar') || lower.contains('라이어')) return liarsPoker;
    if (lower.contains('final') || lower.contains('파이널')) return finalCall;
    if (lower.contains('mafia') || lower.contains('마피아')) return mafia;
    return fallback;
  }
}

/// 시안 크기(1040×680)로 그린 판을 화면에 맞춰 줄입니다.
class MosiGameModalFrame extends StatelessWidget {
  const MosiGameModalFrame({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.fromLTRB(34, 30, 34, 30),
    this.semanticLabel,
  });

  static const Size designSize = Size(1040, 680);

  final Widget child;
  final MosiGameModalTheme theme;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.height;
        // 1194×834 화면에서 시안과 같은 비율(약 87%·82%)이 되도록 맞춥니다.
        final scale = math.min(
          math.min(
            width * 0.87 / designSize.width,
            height * 0.82 / designSize.height,
          ),
          1.4,
        );
        return Semantics(
          scopesRoute: true,
          namesRoute: semanticLabel != null,
          label: semanticLabel,
          explicitChildNodes: true,
          child: SizedBox(
            width: (designSize.width + 12) * scale,
            height: (designSize.height + 12) * scale,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: designSize.width + 12,
                height: designSize.height + 12,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: designSize.width,
                    height: designSize.height,
                    padding: padding,
                    decoration: BoxDecoration(
                      color: MosiColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MosiColors.ink, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent,
                          offset: const Offset(12, 12),
                        ),
                      ],
                    ),
                    // Slider·InkWell이 Material을 찾을 수 있게 한 겹 둡니다.
                    child: Material(
                      type: MaterialType.transparency,
                      child: DefaultTextStyle(
                        style: MosiFonts.sans(color: MosiColors.navy),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 모달 오른쪽 위 네모 닫기 단추(✕).
class MosiSquareCloseButton extends StatelessWidget {
  const MosiSquareCloseButton({
    super.key,
    required this.onPressed,
    this.size = 48,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '닫기',
      child: Semantics(
        button: true,
        label: '닫기',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: MosiColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MosiColors.ink, width: 3),
            ),
            child: Icon(
              Icons.close_rounded,
              size: size * 0.5,
              color: MosiColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 크림색 칸(설정 모달 안의 게임·방 정보·소리 칸).
class MosiCreamPanel extends StatelessWidget {
  const MosiCreamPanel({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MosiColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MosiColors.ink, width: 2),
      ),
      child: child,
    );
  }
}
