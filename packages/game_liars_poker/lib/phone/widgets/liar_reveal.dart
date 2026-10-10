// [liar_reveal.dart] LIAR 공개 뒤 휴대폰마다 다른 판정 화면과
// 룰렛 결과 화면을 구성하는 파일이다.
//
// - 간파한 사람: 간파 성공과 이번 판 안전 안내
// - 간파 당한 사람: 들킴 도장과 벌칙 룰렛 확률, 레버 안내
// - 나머지: 두 사람의 대결과 룰렛을 돌릴 사람 안내

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/shared/animations/progress_sound_cue.dart';
import 'package:game_kit/sound/app_sounds.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

/// LIAR가 거짓을 밝혀낸 순간, 내 역할에 맞는 화면입니다.
class PhoneLiarReveal extends StatelessWidget {
  const PhoneLiarReveal({
    super.key,
    required this.meUid,
    required this.caller,
    required this.caught,
  });

  final String meUid;

  /// LIAR를 외친 사람입니다. 판정 도중 재접속하면 모를 수 있습니다.
  final PhoneGamePlayer? caller;

  /// 거짓이 들켜 룰렛을 돌리는 사람입니다.
  final PhoneGamePlayer caught;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (caught.uid == meUid) {
      body = _CaughtView(caught: caught, caller: caller);
    } else if (caller?.uid == meUid) {
      body = _CallerView(caller: caller!, caught: caught);
    } else {
      body = _OtherView(caller: caller, caught: caught);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + (landscape ? 64 : 76),
            24,
            MediaQuery.paddingOf(context).bottom + (landscape ? 12 : 34),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 354,
              height: math.max(
                landscape ? 520.0 : 640.0,
                constraints.maxHeight -
                    MediaQuery.paddingOf(context).vertical -
                    (landscape ? 76 : 110),
              ),
              child: body,
            ),
          ),
        );
      },
    );
  }
}

class _CallerView extends StatelessWidget {
  const _CallerView({required this.caller, required this.caught});

  final PhoneGamePlayer caller;
  final PhoneGamePlayer caught;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(top: 30, child: _GoldRays(size: 560)),
        Column(
          children: [
            const Spacer(),
            const NoirLiarMark(),
            const SizedBox(height: 22),
            SizedBox(
              width: 200,
              height: 196,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  NoirAvatar(
                    characterId: caller.characterId,
                    size: 190,
                    ringColor: LiarsPokerColors.gold,
                    ringWidth: 7,
                    glowColor: LiarsPokerColors.gold.withValues(alpha: .45),
                  ),
                  Positioned(
                    right: -10,
                    bottom: 4,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LiarsPokerColors.gold,
                        border: Border.all(
                          color: LiarsPokerColors.night,
                          width: 5,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 34,
                        color: LiarsPokerColors.night,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              '간파 성공!',
              style: LiarsPokerFonts.headline(
                size: 52,
                color: LiarsPokerColors.goldLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${caught.nickname}의 거짓을 밝혀냈어요',
              style: LiarsPokerFonts.text(
                size: 17,
                color: LiarsPokerColors.mutedLight,
              ),
            ),
            const Spacer(),
            Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LiarsPokerColors.gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LiarsPokerColors.gold, width: 2),
              ),
              child: Text(
                '이번 판은 안전해요',
                style: LiarsPokerFonts.text(
                  size: 17,
                  weight: FontWeight.w700,
                  color: LiarsPokerColors.goldLight,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SpinnerRow(player: caught),
          ],
        ),
      ],
    );
  }
}

class _CaughtView extends StatelessWidget {
  const _CaughtView({required this.caught, required this.caller});

  final PhoneGamePlayer caught;
  final PhoneGamePlayer? caller;

  @override
  Widget build(BuildContext context) {
    final odds = liarsPokerRouletteOdds(caught.penaltyCount);
    final callerName = caller?.nickname;
    return Column(
      children: [
        const Spacer(),
        const NoirLiarMark(),
        const SizedBox(height: 22),
        SizedBox(
          width: 190,
          height: 176,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              NoirAvatar(
                characterId: caught.characterId,
                size: 170,
                ringColor: LiarsPokerColors.red,
                ringWidth: 7,
                glowColor: LiarsPokerColors.red.withValues(alpha: .45),
              ),
              Positioned(
                left: -16,
                bottom: 18,
                child: Transform.rotate(
                  angle: -14 * math.pi / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: LiarsPokerColors.ivory.withValues(alpha: .92),
                      border: Border.all(color: LiarsPokerColors.red, width: 5),
                    ),
                    child: Text(
                      '들킴',
                      style: LiarsPokerFonts.headline(
                        size: 30,
                        color: LiarsPokerColors.red,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('거짓이 밝혀졌습니다.', style: LiarsPokerFonts.headline(size: 34)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              if (callerName != null) ...[
                TextSpan(
                  text: callerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LiarsPokerColors.ivory,
                  ),
                ),
                const TextSpan(text: '에게 간파당했어요'),
              ] else
                const TextSpan(text: '간파당했어요'),
            ],
          ),
          style: LiarsPokerFonts.text(
            size: 17,
            color: LiarsPokerColors.mutedLight,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: LiarsPokerColors.redPanel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: LiarsPokerColors.red, width: 3),
            boxShadow: [
              BoxShadow(
                color: LiarsPokerColors.red.withValues(alpha: .25),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            children: [
              Text('벌칙 룰렛', style: LiarsPokerFonts.headline(size: 26)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${odds.total}칸 중 탈락',
                    style: LiarsPokerFonts.text(
                      size: 15,
                      color: LiarsPokerColors.pinkLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${odds.bad}',
                    style: LiarsPokerFonts.western(
                      size: 44,
                      color: LiarsPokerColors.pink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '칸',
                    style: LiarsPokerFonts.text(
                      size: 15,
                      color: LiarsPokerColors.pinkLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NoirOddsLadder(penaltyCount: caught.penaltyCount),
              const SizedBox(height: 12),
              Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LiarsPokerColors.red,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: LiarsPokerColors.redDeep,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  '태블릿 옆 레버를 당기세요',
                  style: LiarsPokerFonts.text(
                    size: 17,
                    weight: FontWeight.w700,
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

class _OtherView extends StatelessWidget {
  const _OtherView({required this.caller, required this.caught});

  final PhoneGamePlayer? caller;
  final PhoneGamePlayer caught;

  @override
  Widget build(BuildContext context) {
    final knownCaller = caller;
    return Column(
      children: [
        const Spacer(),
        const NoirLiarMark(size: 56),
        const SizedBox(height: 34),
        Row(
          mainAxisAlignment: knownCaller == null
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            if (knownCaller != null) ...[
              _Duelist(
                player: knownCaller,
                tag: '간파 성공',
                color: LiarsPokerColors.gold,
                tagText: LiarsPokerColors.night,
              ),
              Text(
                'VS',
                style: LiarsPokerFonts.western(
                  size: 30,
                  color: LiarsPokerColors.dim,
                ),
              ),
            ],
            _Duelist(
              player: caught,
              tag: '거짓 들킴',
              color: LiarsPokerColors.red,
              tagText: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 34),
        Text(
          '${caught.nickname}${liarsPokerSubjectParticle(caught.nickname)} 룰렛을 돌려요',
          style: LiarsPokerFonts.headline(size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          '태블릿을 함께 봐주세요',
          style: LiarsPokerFonts.text(size: 16, color: LiarsPokerColors.muted),
        ),
        const Spacer(),
        Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LiarsPokerColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LiarsPokerColors.panelEdge),
          ),
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: '나는 이번 판 '),
                TextSpan(
                  text: '안전해요',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LiarsPokerColors.ivory,
                  ),
                ),
              ],
            ),
            style: LiarsPokerFonts.text(
              size: 16,
              color: LiarsPokerColors.mutedLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _Duelist extends StatelessWidget {
  const _Duelist({
    required this.player,
    required this.tag,
    required this.color,
    required this.tagText,
  });

  final PhoneGamePlayer player;
  final String tag;
  final Color color;
  final Color tagText;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    child: Column(
      children: [
        NoirAvatar(
          characterId: player.characterId,
          size: 120,
          ringColor: color,
          ringWidth: 6,
          glowColor: color.withValues(alpha: .35),
        ),
        const SizedBox(height: 10),
        Text(
          player.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LiarsPokerFonts.text(size: 18, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tag,
            style: LiarsPokerFonts.text(
              size: 14,
              weight: FontWeight.w700,
              color: tagText,
            ),
          ),
        ),
      ],
    ),
  );
}

/// `민준이 룰렛을 돌려요 · 탈락 4/16` 한 줄입니다.
class _SpinnerRow extends StatelessWidget {
  const _SpinnerRow({required this.player});

  final PhoneGamePlayer player;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: LiarsPokerColors.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: LiarsPokerColors.panelEdge),
    ),
    child: Row(
      children: [
        NoirAvatar(
          characterId: player.characterId,
          size: 32,
          ringColor: LiarsPokerColors.red,
          ringWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: player.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '${liarsPokerSubjectParticle(player.nickname)} 룰렛을 돌려요',
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LiarsPokerFonts.text(size: 15),
          ),
        ),
        NoirOddsPill(penaltyCount: player.penaltyCount),
      ],
    ),
  );
}

/// 금색 빛줄기가 가운데에서 퍼지는 배경입니다.
class _GoldRays extends StatelessWidget {
  const _GoldRays({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ShaderMask(
      shaderCallback: (rect) => const RadialGradient(
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, .3, .7],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _RaysPainter(),
      ),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final paint = Paint()..color = LiarsPokerColors.gold.withValues(alpha: .1);
    const step = 15 * math.pi / 180;
    const ray = 6 * math.pi / 180;
    for (var angle = 0.0; angle < math.pi * 2; angle += step) {
      canvas.drawArc(rect, angle, ray, true, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 룰렛 결과
// ---------------------------------------------------------------------------
/// 모든 휴대폰이 함께 보는 룰렛 결과입니다. 생존은 금색, 탈락은 빨강입니다.
class PhoneRouletteResult extends StatefulWidget {
  const PhoneRouletteResult({
    super.key,
    required this.player,
    required this.eliminated,
    required this.isMe,
  });

  final PhoneGamePlayer player;
  final bool eliminated;
  final bool isMe;

  @override
  State<PhoneRouletteResult> createState() => _PhoneRouletteResultState();
}

class _PhoneRouletteResultState extends State<PhoneRouletteResult>
    with SingleTickerProviderStateMixin {
  // 결과 화면이 자리 잡은 뒤(약 0.3초) 도장이 크게 내려와 찍힙니다.
  static const _stampStart = .38;

  late final AnimationController _stamp =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 840),
        )
        ..addListener(_playStamp)
        ..forward();
  final _stampCue = ProgressSoundCue();

  double get _stampProgress =>
      ((_stamp.value - _stampStart) / (1 - _stampStart)).clamp(0.0, 1.0);

  void _playStamp() {
    if (!mounted) return;
    _stampCue.maybePlay(
      context,
      AppSounds.stamp,
      value: _stampProgress,
      threshold: .55,
    );
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.eliminated
        ? LiarsPokerColors.red
        : LiarsPokerColors.gold;
    final word = widget.eliminated ? '탈락' : '생존';
    final footer = widget.eliminated
        ? widget.isMe
              ? '이제 휴대폰에서 관전할 수 있어요'
              : '곧 다음 라운드가 시작돼요'
        : '곧 다음 라운드가 시작돼요';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 76,
        24,
        MediaQuery.paddingOf(context).bottom + 34,
      ),
      child: Column(
        children: [
          const Spacer(),
          Text(
            '룰렛 결과',
            style: LiarsPokerFonts.text(
              size: 15,
              color: LiarsPokerColors.muted,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 22),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.square(
                dimension: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    NoirAvatar(
                      characterId: widget.player.characterId,
                      size: 220,
                      ringColor: color,
                      ringWidth: 7,
                      glowColor: color.withValues(alpha: .35),
                      grayscale: widget.eliminated,
                    ),
                    AnimatedBuilder(
                      animation: _stamp,
                      builder: (context, child) {
                        final progress = _stampProgress;
                        final t = Curves.easeOutBack.transform(progress);
                        return Opacity(
                          opacity: (progress * 2).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 2.2 - 1.2 * t,
                            child: child,
                          ),
                        );
                      },
                      child: Transform.rotate(
                        angle: -12 * math.pi / 180,
                        child: Container(
                          width: 176,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LiarsPokerColors.night.withValues(
                              alpha: .72,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color, width: 6),
                          ),
                          child: Text(
                            word,
                            style: LiarsPokerFonts.headline(
                              size: 48,
                              color: widget.eliminated
                                  ? LiarsPokerColors.pink
                                  : LiarsPokerColors.goldLight,
                              letterSpacing: 4.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            '${widget.player.nickname} $word',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LiarsPokerFonts.headline(size: 36),
          ),
          const Spacer(),
          Text(
            footer,
            style: LiarsPokerFonts.text(
              size: 14,
              color: LiarsPokerColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
