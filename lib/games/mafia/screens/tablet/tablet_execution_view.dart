import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 처형 발표==============================
/// 개표 뒤 처형자를 알리고 신분을 공개합니다.
///
/// 시안 세 장이 한 연출입니다.
///
/// | 박자 | 시안 | 내용 |
/// |---|---|---|
/// | 1 | `tablet-p7 투표 결과발표` | `탈락자 닉네임` 64px |
/// | 2 | `1017:555` | 뒷면 카드 + 대상의 원형 사진 |
/// | 3 | `1017:566` | 앞면 카드 + "○○님은 ○○이었습니다." |
///
/// **카드가 박자 2 → 3에서 31px 올라갑니다.** 실수가 아니라 필요한 이동입니다.
/// 박자 2 위치에 그대로 두면 카드 아래끝(628)이 문구(627)와 겹칩니다. 그래서
/// 뒤집기와 함께 올라가도록 이었습니다.
class MafiaTabletExecutionView extends StatefulWidget {
  const MafiaTabletExecutionView({
    super.key,
    required this.executed,
    required this.executedRole,
    required this.isTie,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  /// 처형된 사람입니다. 동표로 무처형이면 null입니다.
  final MafiaPlayer? executed;

  /// 처형된 사람의 신분입니다. 서버가 공개한 값을 그대로 씁니다.
  final MafiaRole? executedRole;

  /// 동표로 아무도 처형되지 않았는지입니다.
  final bool isTie;

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  //=======================연출 시간==============================
  /// 이름을 보여 주는 시간입니다(확정: 4초). 이 뒤에 카드가 나옵니다.
  static const Duration nameHold = Duration(milliseconds: 4000);

  /// 뒷면 카드를 보여 주는 시간입니다. 이 뒤에 뒤집혀 공개 5초가 이어집니다.
  static const Duration cardHold = Duration(milliseconds: 1000);

  /// 카드가 뒤집히는 시간입니다. 휴대폰과 같게 맞췄습니다.
  static const Duration flipDuration = Duration(milliseconds: 620);

  @override
  State<MafiaTabletExecutionView> createState() =>
      _MafiaTabletExecutionViewState();
}

class _MafiaTabletExecutionViewState extends State<MafiaTabletExecutionView>
    with SingleTickerProviderStateMixin {
  //=======================시안 기준 좌표==============================
  static const double _nameTop = 378;

  /// 뒤집기 전 카드 위치입니다(박자 2).
  static const Rect _cardBefore = Rect.fromLTWH(454, 209, 286, 419.39);

  /// 뒤집은 뒤 카드 위치입니다(박자 3). 문구 자리를 만들려고 31px 올라갑니다.
  static const Rect _cardAfter = Rect.fromLTWH(454, 178, 286, 419.39);

  static const Rect _portrait = Rect.fromLTWH(539, 356, 116, 116);
  static const double _sentenceTop = 627;

  late final AnimationController _flip;
  Timer? _nameTimer;
  Timer? _cardTimer;
  bool _showsCard = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: MafiaTabletExecutionView.flipDuration,
    );
    if (widget.executed == null) return;

    _nameTimer = Timer(MafiaTabletExecutionView.nameHold, () {
      if (!mounted) return;
      setState(() => _showsCard = true);
      _cardTimer = Timer(MafiaTabletExecutionView.cardHold, () {
        if (mounted) _flip.forward();
      });
    });
  }

  @override
  void dispose() {
    _nameTimer?.cancel();
    _cardTimer?.cancel();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final executed = widget.executed;

    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletSun(),
        if (executed == null)
          MafiaTabletHeadline(
            text: widget.isTie ? '표가 같아 아무도 처형되지 않았습니다' : '처형된 사람이 없습니다',
            top: _nameTop,
          )
        else if (!_showsCard)
          MafiaTabletHeadline(text: executed.nickname, top: _nameTop)
        else
          ..._buildCardStage(executed),
        MafiaTabletChrome(
          onRulebookPressed: widget.onRulebookPressed,
          onSettingsPressed: widget.onSettingsPressed,
        ),
      ],
    );
  }

  List<Widget> _buildCardStage(MafiaPlayer executed) {
    return [
      AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final progress = _flip.value;
          // 뒤집는 동안 카드가 문구 자리를 만들며 올라갑니다.
          final rect = Rect.lerp(_cardBefore, _cardAfter, progress)!;
          return MafiaTabletBox(
            rect: rect,
            child: _buildCard(executed, progress),
          );
        },
      ),
      AnimatedBuilder(
        animation: _flip,
        builder: (context, child) {
          // 뒤집기 후반부에 맞춰 문구가 떠오릅니다.
          final opacity = ((_flip.value - 0.5) * 2).clamp(0.0, 1.0);
          return Opacity(opacity: opacity, child: child);
        },
        child: MafiaTabletHeadline(
          text: widget.executedRole == null
              ? MafiaCopy.unknownRole(executed.nickname)
              : MafiaCopy.wasRole(
                  executed.nickname,
                  widget.executedRole!.displayName,
                ),
          top: _sentenceTop,
          fontSize: 24,
        ),
      ),
    ];
  }

  Widget _buildCard(MafiaPlayer executed, double progress) {
    final back = Assets.games.mafia.images.cards.roleBack.game;
    final front = widget.executedRole?.card;
    // 절반을 지나면 앞면으로 바꿔, 뒤집히는 도중에 글자가 반사되어 보이지
    // 않게 합니다.
    final showsFront = progress >= 0.5 && front != null;
    final angle = showsFront ? math.pi * (1 - progress) : math.pi * progress;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              (showsFront ? front : back).image(
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
              // 뒷면 위에 얹힌 대상의 원형 사진입니다. 뒤집기 전반부에 사라집니다.
              if (!showsFront) _buildPortrait(progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(double progress) {
    final opacity = (1 - progress * 2).clamp(0.0, 1.0);
    if (opacity == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 카드 안쪽 비율로 옮깁니다. 카드가 움직여도 사진이 같은 자리에 붙습니다.
        final scale = constraints.maxWidth / _cardBefore.width;
        return Stack(
          children: [
            Positioned(
              left: (_portrait.left - _cardBefore.left) * scale,
              top: (_portrait.top - _cardBefore.top) * scale,
              width: _portrait.width * scale,
              height: _portrait.height * scale,
              child: Opacity(
                opacity: opacity,
                child: ClipOval(
                  child: MafiaProfileImage(
                    url: widget.executed?.profileImageUrl ?? '',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
