part of '../game_screen.dart';

/// 잔여카드를 가진 마지막 플레이어의 손패를 잠그고 FOLD 선택을 표시합니다.
class _FoldPrompt extends StatelessWidget {
  const _FoldPrompt({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final foldButton = LiarsPokerPressableAssetButton(
      asset: Assets.games.liarsPoker.images.button.buttonFold.game,
      // width: isLandscape ? 190 : 255.w,
      width: isLandscape ? 190 : 255.w,
      enabled: enabled,
      semanticsLabel: 'FOLD하고 패널티 진행',
      onPressed: onPressed,
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 18 : 26.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              foldButton,
              SizedBox(height: isLandscape ? 8 : 12.h),
              Text(
                'FOLD를 선택하면 내가 패널티를 진행합니다.\n'
                'LIAR 판정에 실패하면 이번 패널티 확률이 증가합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLandscape ? 13 : 13.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
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
    required double bottomSafeArea,
  }) {
    final height = size.height;
    final width = size.width;
    final headerTop = (height * 0.059).clamp(32.0, 56.0);
    final timerTop = (height * 0.124).clamp(78.0, 112.0);
    final statusTop = (height * 0.19).clamp(122.0, 166.0);
    final handTop = (height * 0.251).clamp(164.0, 218.0);
    // 화면 실제 높이를 기준으로 버튼·턴 정보·배치 영역이 같은 높이를
    // 사용합니다. ScreenUtil 높이와 LayoutBuilder 높이를 섞으면 작은 기기에서
    // 1~수 px 차이로 RenderFlex overflow가 발생할 수 있습니다.
    final actionHeight = (height * 0.225).clamp(140.0, 193.0);
    final actionBottom = math.max(
      bottomSafeArea + 4,
      (height * 0.045).clamp(18.0, 42.0),
    );
    final preferredActionTop = math.max(
      handTop + (height * 0.245).clamp(190.0, 210.0),
      height - actionHeight - actionBottom,
    );
    // 부동소수점 반올림과 하단 시스템 영역까지 고려해 안전 여백을 둡니다.
    final actionTop = math.min(
      preferredActionTop,
      math.max(handTop, height - actionHeight - actionBottom),
    );
    final handBottom = actionTop - (height * 0.025).clamp(14.0, 24.0);
    // 작은 화면에서 최소 높이를 강제하지 않습니다. 손패 위젯이 주어진 공간에
    // 맞춰 카드 크기와 간격을 자체 축소하므로 영역끼리 겹치지 않습니다.
    final handHeight = math.max(1.0, handBottom - handTop);

    return _PortraitGameLayout(
      headerTop: headerTop,
      timerTop: timerTop,
      statusTop: statusTop,
      handTop: handTop,
      handHeight: handHeight,
      actionTop: actionTop,
      actionHeight: actionHeight,
      horizontalPadding: (width * 0.051).clamp(16.0, 24.0),
      messagePadding: (width * 0.062).clamp(20.0, 30.0),
      actionHorizontalPadding: (width * 0.18).clamp(54.0, 82.0),
      tableHeight: (height * 0.0285).clamp(20.0, 26.0),
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
  const _PhoneGameBackground({required this.isLandscape});

  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final asset = isLandscape
        ? Assets.games.liarsPoker.images.background.background.game
        : Assets.games.liarsPoker.images.background.backgroundPhone.game;

    return asset.image(fit: BoxFit.cover, filterQuality: FilterQuality.high);
  }
}
