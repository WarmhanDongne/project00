import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_action_switcher.dart';

/// 턴 플레이어 정보와 같은 프로필 표현을 사용하는 휴대폰 벌칙 상태입니다.
class PhonePenaltyStatus extends StatelessWidget {
  const PhonePenaltyStatus({
    super.key,
    required this.player,
    required this.result,
  });

  final PhoneGamePlayer? player;
  final String? result;

  bool get _isSafe => result == 'safe';
  bool get _isEliminated => result == 'eliminated';

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final profile = player == null
        ? _ProfileFallback(size: isLandscape ? 92 : 94.w)
        : PhonePlayerProfile(player: player!, size: isLandscape ? 92 : 94.w);
    final information = _PenaltyInformation(
      nickname: player?.nickname ?? '플레이어',
      result: result,
      resultColor: _isSafe
          ? const Color(0xFF45D483)
          : _isEliminated
          ? const Color(0xFFFF3B30)
          : Colors.white,
    );

    return IgnorePointer(
      child: Center(
        child: isLandscape
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [profile, const SizedBox(width: 22), information],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('벌칙 진행 중', style: _PenaltyTextStyle.title),
                  SizedBox(height: 14.h),
                  profile,
                  SizedBox(height: 10.h),
                  _PenaltyInformation(
                    nickname: player?.nickname ?? '플레이어',
                    result: result,
                    resultColor: _isSafe
                        ? const Color(0xFF45D483)
                        : _isEliminated
                        ? const Color(0xFFFF3B30)
                        : Colors.white,
                    showTitle: false,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PenaltyInformation extends StatelessWidget {
  const _PenaltyInformation({
    required this.nickname,
    required this.result,
    required this.resultColor,
    this.showTitle = true,
  });

  final String nickname;
  final String? result;
  final Color resultColor;
  final bool showTitle;

  String? get _resultText => switch (result) {
    'safe' => '생존',
    'eliminated' => '탈락',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLandscape
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (showTitle) ...[
          const Text('벌칙 진행 중', style: _PenaltyTextStyle.title),
          const SizedBox(height: 8),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isLandscape ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // 결과가 도착하기 전부터 값 영역을 확보해 '결과:'의 위치를 고정합니다.
          width: 154,
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '결과:',
                  textAlign: isLandscape ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) {
                    final scale = Tween<double>(begin: 1.38, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: scale,
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _resultText ?? '',
                    key: ValueKey(_resultText),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  const _ProfileFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.4),
    );
  }
}

abstract final class _PenaltyTextStyle {
  static const title = TextStyle(
    fontFamily: 'BebasNeue',
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    shadows: [Shadow(color: Colors.black, blurRadius: 12)],
  );
}
