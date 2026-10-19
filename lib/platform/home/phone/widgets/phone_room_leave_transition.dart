import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';

enum PhoneRoomLeaveStage { idle, leaving, failed }

/// 대기실을 보존한 채 퇴장 요청의 체감 전환만 담당합니다.
///
/// 실제 퇴장 성공과 재시도 가능 여부는 [RoomProvider]가 결정합니다. 이 위젯은
/// 서버 결과를 미리 확정하지 않고, 요청 중에는 내용을 빠져나가게 보이며 실패하면
/// 같은 대기실을 다시 드러냅니다.
class PhoneRoomLeaveTransition extends StatelessWidget {
  const PhoneRoomLeaveTransition({
    super.key,
    required this.stage,
    required this.progress,
    required this.gameId,
    required this.onRetry,
    required this.onReturn,
    required this.child,
    this.errorMessage,
    this.transitionTitle,
    this.transitionSubtitle,
  });

  final PhoneRoomLeaveStage stage;
  final Animation<double> progress;
  final String? gameId;
  final VoidCallback onRetry;
  final VoidCallback onReturn;
  final Widget child;
  final String? errorMessage;
  final String? transitionTitle;
  final String? transitionSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = MosiGameArt.of(gameId ?? '').shelfTheme;
    final background = gameId?.isNotEmpty == true
        ? theme.ground
        : MosiColors.violet;
    final foreground = background.computeLuminance() < .42
        ? MosiColors.white
        : MosiColors.navy;
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(progress.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: stage != PhoneRoomLeaveStage.idle,
              child: child,
            ),
            if (stage == PhoneRoomLeaveStage.leaving || t > 0)
              IgnorePointer(
                child: PhoneBackgroundReveal(
                  key: const Key('phone-room-leaving-background'),
                  color: background,
                  progress: t,
                ),
              ),
            if (stage == PhoneRoomLeaveStage.leaving || t > 0)
              Opacity(
                opacity: t,
                child: _LeavingRoomView(
                  key: const Key('phone-room-leaving'),
                  foreground: foreground,
                  progress: t,
                  title: transitionTitle,
                  subtitle: transitionSubtitle,
                ),
              ),
            if (stage == PhoneRoomLeaveStage.failed)
              _LeaveFailurePanel(
                key: const Key('phone-room-leave-failed'),
                errorMessage: errorMessage,
                onRetry: onRetry,
                onReturn: onReturn,
              ),
          ],
        );
      },
    );
  }
}

class _LeavingRoomView extends StatelessWidget {
  const _LeavingRoomView({
    super.key,
    required this.foreground,
    required this.progress,
    this.title,
    this.subtitle,
  });

  final Color foreground;
  final double progress;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _FlyingPaper(
            alignment: Alignment.topLeft,
            angle: -.12,
            offset: Offset(-32 * progress, -18 * progress),
          ),
          _FlyingPaper(
            alignment: Alignment.topRight,
            angle: .14,
            offset: Offset(38 * progress, -12 * progress),
          ),
          _FlyingPaper(
            alignment: Alignment.bottomLeft,
            angle: .12,
            offset: Offset(-36 * progress, 22 * progress),
          ),
          Center(
            child: Semantics(
              liveRegion: true,
              label:
                  title ??
                  GameLocale.select(
                    ko: '그룹에서 나가는 중이에요',
                    en: 'Leaving the room',
                    zhHans: '正在离开房间',
                    zhHant: '正在離開房間',
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ExitDoor(),
                  const SizedBox(height: 22),
                  const _LeavingDots(),
                  const SizedBox(height: 24),
                  Text(
                    title ??
                        GameLocale.select(
                          ko: '그룹에서 나가는 중이에요',
                          en: 'Leaving the room',
                          zhHans: '正在离开房间',
                          zhHant: '正在離開房間',
                        ),
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 25,
                      weight: FontWeight.w700,
                      color: foreground,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle ??
                        GameLocale.select(
                          ko: '잠시만 기다려 주세요',
                          en: 'Please wait a moment',
                          zhHans: '请稍候',
                          zhHant: '請稍候',
                        ),
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 15,
                      color: foreground.withValues(alpha: .76),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitDoor extends StatelessWidget {
  const _ExitDoor();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.045,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 10,
          top: 8,
          child: Container(
            width: 72,
            height: 94,
            decoration: BoxDecoration(
              color: MosiColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Container(
          width: 72,
          height: 94,
          decoration: BoxDecoration(
            color: MosiColors.lime,
            border: Border.all(color: MosiColors.ink, width: 4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            alignment: const Alignment(.52, .06),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: MosiColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          right: -12,
          top: 10,
          bottom: -1,
          child: Container(
            width: 15,
            decoration: BoxDecoration(
              color: MosiColors.white,
              border: Border.all(color: MosiColors.ink, width: 4),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(6),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LeavingDots extends StatefulWidget {
  const _LeavingDots();

  @override
  State<_LeavingDots> createState() => _LeavingDotsState();
}

class _LeavingDotsState extends State<_LeavingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _dotColor(index),
              shape: BoxShape.circle,
              border: Border.all(color: MosiColors.navy, width: 1.5),
            ),
          ),
        ],
      ],
    ),
  );

  Color _dotColor(int index) {
    final phase = (_controller.value * 3).floor() % 3;
    return phase == index ? MosiColors.lime : MosiColors.white;
  }
}

class _FlyingPaper extends StatelessWidget {
  const _FlyingPaper({
    required this.alignment,
    required this.angle,
    required this.offset,
  });

  final Alignment alignment;
  final double angle;
  final Offset offset;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 148,
          height: 64,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MosiColors.white.withValues(alpha: .9),
            border: Border.all(color: MosiColors.ink, width: 3),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LeaveFailurePanel extends StatelessWidget {
  const _LeaveFailurePanel({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.onReturn,
  });

  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ModalBarrier(dismissible: false, color: Color(0x240E0A3D)),
      SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 82, 18, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F5),
              border: Border.all(color: MosiColors.red, width: 3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: MosiColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: MosiColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GameLocale.select(
                              ko: '그룹에서 나가지 못했어요',
                              en: 'Could not leave the room',
                              zhHans: '无法离开房间',
                              zhHant: '無法離開房間',
                            ),
                            style: MosiFonts.sans(
                              locale: Localizations.maybeLocaleOf(context),
                              size: 18,
                              weight: FontWeight.w700,
                              color: MosiColors.red,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            errorMessage ??
                                GameLocale.select(
                                  ko: '연결을 확인하고 다시 시도해 주세요',
                                  en: 'Check your connection and try again',
                                  zhHans: '请检查网络连接后重试',
                                  zhHant: '請檢查網路連線後重試',
                                ),
                            style: MosiFonts.sans(
                              locale: Localizations.maybeLocaleOf(context),
                              size: 13,
                              color: MosiColors.navy,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: MosiButton(
                        label: GameLocale.select(
                          ko: '대기실로 돌아가기',
                          en: 'View waiting room',
                          zhHans: '返回等候室',
                          zhHant: '返回等候室',
                        ),
                        variant: MosiButtonVariant.outline,
                        height: 48,
                        fontSize: 13,
                        shadowOffset: 3,
                        expand: true,
                        onPressed: onReturn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MosiButton(
                        label: GameLocale.select(
                          ko: '다시 시도',
                          en: 'Retry',
                          zhHans: '重试',
                          zhHant: '重試',
                        ),
                        background: MosiColors.lime,
                        foreground: MosiColors.navy,
                        height: 48,
                        fontSize: 14,
                        shadowOffset: 3,
                        expand: true,
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
