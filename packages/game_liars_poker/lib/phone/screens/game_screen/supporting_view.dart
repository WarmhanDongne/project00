part of '../game_screen.dart';

/// 잔여카드를 가진 마지막 플레이어의 손패를 잠그고 FOLD 선택을 표시합니다.
///
/// 아래 행동 자리의 Liar 퍽과 같은 모양이며, 포기를 뜻하도록 어두운 링을
/// 두릅니다.
class _FoldPrompt extends StatefulWidget {
  const _FoldPrompt({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_FoldPrompt> createState() => _FoldPromptState();
}

class _FoldPromptState extends State<_FoldPrompt> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 22.w),
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 14 : 20, 20, 18),
          decoration: BoxDecoration(
            color: LiarsPokerColors.night.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: LiarsPokerColors.panelEdge, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '남은 카드는 나 혼자예요',
                style: LiarsPokerFonts.headline(size: isLandscape ? 22 : 26),
              ),
              SizedBox(height: isLandscape ? 12 : 16),
              Semantics(
                button: true,
                enabled: widget.enabled,
                label: 'FOLD하고 벌칙 룰렛 진행',
                excludeSemantics: true,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapCancel: () => setState(() => _pressed = false),
                  onTapUp: (_) {
                    setState(() => _pressed = false);
                    widget.onPressed();
                  },
                  child: NoirPuck(
                    label: 'Fold',
                    ringColor: LiarsPokerColors.dim,
                    size: isLandscape ? 96 : 112,
                    pressed: _pressed,
                    enabled: widget.enabled,
                  ),
                ),
              ),
              SizedBox(height: isLandscape ? 12 : 16),
              Text(
                'Fold를 누르면 의심을 접고 내가 룰렛을 돌려요.\n'
                'Liar로 의심했는데 진실이면 이번 룰렛이 한 단계 더 불리해져요.',
                textAlign: TextAlign.center,
                style: LiarsPokerFonts.text(
                  size: isLandscape ? 12 : 13,
                  color: LiarsPokerColors.mutedLight,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 세로 화면의 실제 크기를 기준으로 주요 영역을 비례 배치합니다.
class _PortraitGameLayout {
  const _PortraitGameLayout({
    required this.headerTop,
    required this.timerTop,
    required this.statusTop,
    required this.handTop,
    required this.handHeight,
    required this.actionTop,
    required this.actionHeight,
    required this.horizontalPadding,
    required this.messagePadding,
    required this.actionHorizontalPadding,
    required this.tableHeight,
    required this.statusFontSize,
    required this.height,
  });

  factory _PortraitGameLayout.fromSize(
    Size size, {
    required double topSafeArea,
    required double bottomSafeArea,
  }) {
    final height = size.height;
    final width = size.width;
    // 시안(402×874): 상단 20 · 헤더 44 · 22 · 기준 카드/시간 128 · 18 ·
    // 손패 · 행동 퍽 128 + 안내 문구 · 하단 34
    final headerTop = topSafeArea + (height * 0.023).clamp(8.0, 20.0);
    final infoTop = headerTop + 48 + (height * 0.025).clamp(10.0, 22.0);
    final infoHeight = (height * 0.146).clamp(92.0, 128.0);
    final actionHeight = (height * 0.19).clamp(136.0, 168.0);
    final actionBottom = math.max(
      bottomSafeArea + 8,
      (height * 0.039).clamp(14.0, 34.0),
    );
    final actionTop = height - actionHeight - actionBottom;
    final handTop = infoTop + infoHeight + (height * 0.02).clamp(8.0, 18.0);
    final handBottom = actionTop - (height * 0.012).clamp(4.0, 10.0);
    // 작은 화면에서 최소 높이를 강제하지 않습니다. 손패 위젯이 주어진 공간에
    // 맞춰 카드 크기와 간격을 자체 축소하므로 영역끼리 겹치지 않습니다.
    final handHeight = math.max(1.0, handBottom - handTop);

    return _PortraitGameLayout(
      headerTop: headerTop,
      timerTop: infoTop,
      statusTop: infoTop + infoHeight + 4,
      handTop: handTop,
      handHeight: handHeight,
      actionTop: actionTop,
      actionHeight: actionHeight,
      horizontalPadding: (width * 0.045).clamp(14.0, 24.0),
      messagePadding: (width * 0.062).clamp(20.0, 30.0),
      actionHorizontalPadding: (width * 0.18).clamp(54.0, 82.0),
      tableHeight: infoHeight,
      statusFontSize: (width * 0.041).clamp(14.0, 17.0),
      height: height,
    );
  }

  final double headerTop;
  final double timerTop;
  final double statusTop;
  final double handTop;
  final double handHeight;
  final double actionTop;
  final double actionHeight;
  final double horizontalPadding;
  final double messagePadding;
  final double actionHorizontalPadding;

  /// 기준 카드·남은 시간 줄의 높이입니다.
  final double tableHeight;
  final double statusFontSize;

  /// 배치 계산에 사용한 화면 높이입니다.
  final double height;

  /// 손패 영역 기준 중앙을 화면 정중앙으로 옮기는 세로 보정값입니다.
  ///
  /// 손패 영역은 상단 정보와 하단 조작부 사이에 있어 화면 정중앙보다 조금
  /// 위에 놓입니다. 그만큼 내려 주어야 안내 문구가 정확히 화면 가운데 뜹니다.
  double get announcementCenterOffsetY =>
      height / 2 - (handTop + handHeight / 2);
}

// ============================================================================
// 가로·세로 공통 배경 위젯
// ============================================================================
class _PhoneGameBackground extends StatelessWidget {
  const _PhoneGameBackground({this.isLandscape = false});

  final bool isLandscape;

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: LiarsPokerColors.night);
}
