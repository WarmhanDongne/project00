import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';

/// 내 턴의 라이어 버튼과 다른 플레이어의 턴 안내를 같은 자리에서 교체합니다.
///
/// 기존 요소는 왼쪽으로 빠지고 새 요소는 오른쪽에서 들어옵니다.
class TurnActionSwitcher extends StatefulWidget {
  const TurnActionSwitcher({
    super.key,
    required this.isRow,
    required this.showLiarButton,
    required this.turnPlayer,
    required this.liarButton,
    required this.height,
    this.alignment = Alignment.center,
    this.profileSize = 100,
    this.nicknameFontSize = 30,
    this.spacing = 10,
  });
  final bool isRow;
  final bool showLiarButton;
  final PhoneGamePlayer? turnPlayer;
  final Widget liarButton;
  final double height;
  final AlignmentGeometry alignment;
  final double profileSize;
  final double nicknameFontSize;
  final double spacing;

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
        isRow: isRow,
        player: player,
        profileSize: profileSize,
        nicknameFontSize: nicknameFontSize,
        spacing: spacing,
      ),
    );
  }

  /// 서로 크기가 다른 버튼과 턴 정보를 같은 전환 영역으로 맞춥니다.
  Widget _buildControlFrame({required Key key, required Widget child}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: height,
      child: RepaintBoundary(
        child: Align(alignment: alignment, child: child),
      ),
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
      height: widget.height,
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

          // 가로 조작부는 오른쪽에 독립된 영역이 있으므로, 퇴장 요소가
          // 왼쪽 손패 영역까지 침범하지 않도록 해당 영역 안에서만 그립니다.
          return widget.isRow ? ClipRect(child: transition) : transition;
        },
      ),
    );
  }
}

/// 현재 턴 플레이어의 프로필과 닉네임을 표시합니다.
class TurnPlayerIndicator extends StatelessWidget {
  const TurnPlayerIndicator({
    super.key,
    required this.isRow,
    required this.player,
    required this.profileSize,
    required this.nicknameFontSize,
    required this.spacing,
  });
  final bool isRow;
  final PhoneGamePlayer player;
  final double profileSize;
  final double nicknameFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return isRow == true
        //================================가로================================
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhonePlayerProfile(player: player, size: profileSize),
              SizedBox(width: spacing),
              Flexible(
                child: Text(
                  '${player.nickname}님\n차례입니다',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nicknameFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        //================================세로================================
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhonePlayerProfile(player: player, size: profileSize),
              SizedBox(width: spacing),
              Flexible(
                child: Text(
                  '${player.nickname}님\n차례입니다',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nicknameFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    final imageUrl = player.profileImageUrl;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final imageCacheSize = (size * pixelRatio).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: Colors.grey,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: imageCacheSize,
              cacheHeight: imageCacheSize,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => _fallbackIcon(),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(Icons.person, color: Colors.white, size: size * 0.4);
  }
}
