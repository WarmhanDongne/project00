// [turn_action_switcher.dart] 현재 턴 상태에 맞게
// 플레이어 프로필과 LIAR·FOLD·SUBMIT 조작을 전환하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';

// ============================================================

/// 내 턴의 라이어 버튼과 다른 플레이어의 턴 안내를 같은 자리에서 교체합니다.
///
/// 기존 요소는 왼쪽으로 빠지고 새 요소는 오른쪽에서 들어옵니다.
class TurnActionSwitcher extends StatefulWidget {
  const TurnActionSwitcher({
    super.key,
    required this.isLandscape,
    required this.showLiarButton,
    required this.turnPlayer,
    required this.liarButton,
    this.portraitControlHeight,
  });
  final bool isLandscape;
  final bool showLiarButton;
  final PhoneGamePlayer? turnPlayer;
  final Widget liarButton;
  final double? portraitControlHeight;

  double get controlHeight =>
      isLandscape ? 170 : portraitControlHeight ?? 193.h.clamp(140.0, 193.0);

  /// 세로 화면은 실제 조작 영역 높이를 기준으로 내부 요소를 계산합니다.
  /// ScreenUtil의 너비·높이 배율이 서로 다른 긴 화면에서도 Column의 합계가
  /// 고정 프레임을 넘지 않도록 프로필·간격·텍스트가 같은 기준을 사용합니다.
  double get profileSize =>
      isLandscape ? 72 : (controlHeight * 0.52).clamp(76.0, 100.0);
  double get nicknameFontSize =>
      isLandscape ? 22 : (controlHeight * 0.15).clamp(20.0, 28.0);
  double get spacing =>
      isLandscape ? 8 : (controlHeight * 0.04).clamp(6.0, 9.0);

  @override
  State<TurnActionSwitcher> createState() => _TurnActionSwitcherState();

  String get _controlId {
    if (showLiarButton) return 'liar-button';
    return turnPlayer == null
        ? 'turn-player-empty'
        : 'turn-player-${turnPlayer!.uid}';
  }

  Widget _buildCurrentControl() {
    if (showLiarButton) {
      return _buildControlFrame(
        key: const ValueKey('liar-button'),
        child: liarButton,
      );
    }

    final player = turnPlayer;
    if (player == null) {
      return _buildControlFrame(
        key: const ValueKey('turn-player-empty'),
        child: const SizedBox.shrink(),
      );
    }

    return _buildControlFrame(
      key: ValueKey('turn-player-${player.uid}'),
      child: TurnPlayerIndicator(
        isLandscape: isLandscape,
        player: player,
        profileSize: profileSize,
        nicknameFontSize: nicknameFontSize,
        spacing: spacing,
      ),
    );
  }

  /// 서로 크기가 다른 버튼과 턴 정보를 같은 전환 영역으로 맞춥니다.
  Widget _buildControlFrame({required Key key, required Widget child}) {
    final fittedChild = isLandscape
        ? Align(alignment: Alignment.center, child: child)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          );

    return SizedBox(
      key: key,
      width: double.infinity,
      height: controlHeight,
      child: RepaintBoundary(child: fittedChild),
    );
  }
}

class _TurnActionSwitcherState extends State<TurnActionSwitcher>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 540);

  late final AnimationController _controller;
  late String _displayedControlId;
  late Widget _displayedControl;
  String? _pendingControlId;
  Widget? _pendingControl;
  bool _hasSwappedControl = true;

  @override
  void initState() {
    super.initState();
    _displayedControlId = widget._controlId;
    _displayedControl = widget._buildCurrentControl();

    _controller =
        AnimationController(
            vsync: this,
            duration: _transitionDuration,
            value: 1,
          )
          ..addListener(_handleAnimationProgress)
          ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(TurnActionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextControlId = widget._controlId;
    final nextControl = widget._buildCurrentControl();

    if (_controller.isAnimating) {
      // 전환 중 도착한 Firebase 알림은 목표 내용만 최신 상태로 교체하고
      // 진행 중인 애니메이션의 시간과 위치는 절대 재시작하지 않습니다.
      if (nextControlId == _pendingControlId) {
        _pendingControl = nextControl;
        if (_hasSwappedControl) _displayedControl = nextControl;
      } else if (nextControlId == _displayedControlId) {
        _displayedControl = nextControl;
      }
      return;
    }

    if (nextControlId == _displayedControlId) {
      _displayedControl = nextControl;
      return;
    }

    _pendingControlId = nextControlId;
    _pendingControl = nextControl;
    _hasSwappedControl = false;
    _controller.forward(from: 0);
  }

  void _handleAnimationProgress() {
    if (_hasSwappedControl || _controller.value < 0.5) return;

    final pendingControlId = _pendingControlId;
    final pendingControl = _pendingControl;
    if (pendingControlId == null || pendingControl == null || !mounted) return;

    // 기존 요소가 완전히 왼쪽으로 빠진 시점에만 내용을 한 번 교체합니다.
    setState(() {
      _displayedControlId = pendingControlId;
      _displayedControl = pendingControl;
      _hasSwappedControl = true;
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _pendingControlId = null;
    _pendingControl = null;
    _hasSwappedControl = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleAnimationProgress);
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.controlHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travelDistance = constraints.maxWidth;

          final transition = AnimatedBuilder(
            animation: _controller,
            child: _displayedControl,
            builder: (context, animatedChild) {
              final value = _controller.value;
              final offsetX = value < 0.5
                  ? -travelDistance * Curves.easeInCubic.transform(value * 2)
                  : travelDistance *
                        (1 - Curves.easeOutCubic.transform((value - 0.5) * 2));

              return Transform.translate(
                offset: Offset(offsetX, 0),
                child: animatedChild,
              );
            },
          );

          // ---------------------------------------------------------------------------
          // 가로 전환 영역 제한
          // ---------------------------------------------------------------------------
          // 가로 조작부는 오른쪽에 독립된 영역이 있으므로, 퇴장 요소가
          // 왼쪽 손패 영역까지 침범하지 않도록 해당 영역 안에서만 그립니다.
          return widget.isLandscape ? ClipRect(child: transition) : transition;
        },
      ),
    );
  }
}

/// 다른 사람 차례에 행동 자리에 보여 주는 안내입니다.
///
/// 얼굴은 위쪽 기준 카드 옆에 이미 크게 보이므로 여기서는 이름과 상태만
/// 퍽 버튼과 같은 무게의 글자로 보여 줍니다.
class TurnPlayerIndicator extends StatelessWidget {
  const TurnPlayerIndicator({
    super.key,
    required this.isLandscape,
    required this.player,
    required this.profileSize,
    required this.nicknameFontSize,
    required this.spacing,
  });
  final bool isLandscape;
  final PhoneGamePlayer player;
  final double profileSize;
  final double nicknameFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 220 : 250.w.clamp(210.0, 300.0),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: player.nickname,
                  style: const TextStyle(color: LiarsPokerColors.goldLight),
                ),
                const TextSpan(text: ' 차례'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LiarsPokerFonts.headline(size: isLandscape ? 26 : 30),
          ),
        ),
        SizedBox(height: spacing + 4),
        Text(
          '카드를 고르는 중이에요',
          style: LiarsPokerFonts.text(size: 13, color: LiarsPokerColors.muted),
        ),
      ],
    );
  }
}

/// 턴 정보와 벌칙 정보가 함께 사용하는 플레이어 프로필입니다.
class PhonePlayerProfile extends StatelessWidget {
  const PhonePlayerProfile({
    super.key,
    required this.player,
    required this.size,
  });

  final PhoneGamePlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: Colors.grey,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        roomCharacterAssetPath(player.characterId),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
