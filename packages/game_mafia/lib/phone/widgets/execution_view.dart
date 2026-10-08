// [execution_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:flutter/material.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/flip_card.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/shared/widgets/profile_image.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/gen/assets.gen.dart';

// ============================================================

/// 처형 발표 화면입니다(Noir 시안: 다른 사람은 포스터, 나는 핏빛 화면).
class MafiaExecutionResultView extends StatelessWidget {
  const MafiaExecutionResultView({
    super.key,
    required this.role,
    required this.executed,
    this.isMe = false,
  });

  final MafiaRole? role;
  final MafiaPlayer? executed;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final target = executed;
        if (target != null && isMe) return _buildSelf(size, scale);
        final posterWidth = 250 * scale;
        final posterHeight = 340 * scale;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, 106),
              child: Text(
                MafiaCopy.executedOtherTitle,
                textAlign: TextAlign.center,
                style: mafiaNoirDisplay(
                  44 * scale,
                  color: MafiaColors.noirInk,
                  height: 1,
                ),
              ),
            ),
            if (target == null)
              const MafiaPhoneAnnouncement(
                beats: [MafiaCopy.noExecution],
                top: MafiaPhoneStatusText.announcementTop,
                fontSize: 30,
              )
            else ...[
              Positioned(
                left: (size.width - posterWidth) / 2,
                top: MafiaPhoneDesign.top(size, 190),
                width: posterWidth,
                height: posterHeight,
                child: MafiaAnnouncementReveal(
                  child: MafiaNoirPoster(
                    player: target,
                    width: posterWidth,
                    height: posterHeight,
                    circleColor: MafiaColors.noirBlood,
                    banner: const MafiaNoirBannerSpec(
                      label: '처 형',
                      top: 0.53,
                      angle: -14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              MafiaPhoneAnnouncement(
                beats: MafiaCopy.executedBeats(target.nickname),
                top: 556,
                fontSize: 26,
              ),
            ],
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }

  /// 내가 처형된 화면입니다(시안 ⑨). 핏빛 줄기 위에 내 신분 카드가 놓입니다.
  Widget _buildSelf(Size size, double scale) {
    final card = role?.card ?? Assets.games.mafia.images.cards.roleBack.game;
    final cardWidth = 240 * scale;
    final cardHeight = 352 * scale;
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: MafiaNoirRays.blood(origin: Alignment(0, -0.2)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, 106),
          child: Text(
            '당신은\n처형 당했습니다',
            textAlign: TextAlign.center,
            style: mafiaNoirDisplay(34 * scale, height: 1.15),
          ),
        ),
        Positioned(
          left: (size.width - cardWidth) / 2,
          top: MafiaPhoneDesign.top(size, 214),
          width: cardWidth,
          height: cardHeight,
          child: MafiaAnnouncementReveal(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(color: MafiaColors.noirBrass, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0x33000000),
                        BlendMode.darken,
                      ),
                      child: card.image(fit: BoxFit.cover),
                    ),
                    MafiaNoirBanner(
                      spec: const MafiaNoirBannerSpec(
                        label: '처형',
                        angle: -16,
                        letterSpacing: 0.4,
                      ),
                      cardWidth: cardWidth,
                      cardHeight: cardHeight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (role != null)
          Positioned(
            left: 0,
            right: 0,
            top: MafiaPhoneDesign.top(size, 590),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '당신의 신분은 '),
                  TextSpan(
                    text: role!.displayName,
                    style: const TextStyle(
                      color: MafiaColors.noirPaper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: MafiaCopy.hasFinalConsonant(role!.displayName)
                        ? '이었습니다.\n'
                        : '였습니다.\n',
                  ),
                  const TextSpan(text: '이제 모든 사람의 신분을 볼 수 있어요.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: mafiaNoirBody(
                16 * scale,
                color: const Color(0xFFA39A86),
                height: 1.6,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, 690),
          child: Text(
            '살아 있는 사람에게 화면을 보여주지 마세요',
            textAlign: TextAlign.center,
            style: mafiaNoirBody(13 * scale, color: const Color(0xFF6E6A5D)),
          ),
        ),
      ],
    );
  }
}

class MafiaExecutionRevealView extends StatefulWidget {
  const MafiaExecutionRevealView({
    super.key,
    required this.myRole,
    required this.executed,
    required this.executedRole,
    this.initiallyRevealed = false,
    this.onRevealed,
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다.
  final MafiaRole? myRole;

  /// 처형된 사람입니다.
  final MafiaPlayer executed;

  /// 처형된 사람의 신분입니다. 서버가 보낸 값을 그대로 씁니다.
  ///
  /// null이면 이 빌드가 모르는 신분이므로 카드를 뒤집지 않습니다.
  final MafiaRole? executedRole;

  /// 재접속 복원용입니다. true면 연출 없이 공개된 상태로 시작합니다.
  final bool initiallyRevealed;

  /// 공개가 끝난 시점에 한 번 호출됩니다.
  final VoidCallback? onRevealed;

  // ---------------------------------------------------------------------------
  // 연출 시간
  // ---------------------------------------------------------------------------
  /// 화면이 뜨고 카드를 뒤집기까지 기다리는 시간입니다.
  static const Duration revealDelay = Duration(milliseconds: 600);

  /// 카드가 뒤집히는 시간입니다. P1 역할 확인과 같게 맞췄습니다.
  static const Duration flipDuration = Duration(milliseconds: 620);

  @override
  State<MafiaExecutionRevealView> createState() =>
      _MafiaExecutionRevealViewState();
}

class _MafiaExecutionRevealViewState extends State<MafiaExecutionRevealView>
    with SingleTickerProviderStateMixin, GamePresentationState {
  @override
  Iterable<AnimationController> get presentationAnimations => [_flipController];
  // ---------------------------------------------------------------------------
  // 시안 기준 좌표
  // ---------------------------------------------------------------------------
  // 시안은 뒤집기 전 카드가 top 208, 뒤집은 후가 top 217로 9px 어긋나 있습니다.
  // 같은 카드가 튀어 보이지 않게 208로 통일했습니다.
  static const double _cardTop = 168;
  static const double _portraitTop = 268;
  static const double _portraitSize = 116;
  static const double _sentenceTop = 576;

  /// 신분 문구의 첫 박자가 머무는 시간입니다.
  static const Duration _sentenceBeatHold = Duration(milliseconds: 1200);

  late final AnimationController _flipController;
  PresentationTimer? _startTimer;

  /// 신분 문구를 찍기 시작했는지입니다. 카드가 절반 돌아가면 붙습니다.
  ///
  /// 반투명하게 미리 깔아 두면 내려찍히는 한 방이 죽습니다.
  bool _showsSentence = false;

  @override
  void initState() {
    super.initState();
    _flipController =
        AnimationController(
            vsync: this,
            duration: MafiaExecutionRevealView.flipDuration,
            value: widget.initiallyRevealed ? 1 : 0,
          )
          ..addStatusListener(_handleFlipStatus)
          ..addListener(_handleFlipProgress);
    // 재접속 복원은 이미 지나간 장면이라 문구가 처음부터 자리에 있습니다.
    _showsSentence = widget.initiallyRevealed;

    if (widget.initiallyRevealed) {
      // 재접속 복원은 연출을 건너뜁니다. 이미 지나간 장면입니다.
      return;
    }
    _startTimer = presentationTimer(MafiaExecutionRevealView.revealDelay, () {
      if (!mounted) return;
      _flipController.forward();
    });
  }

  void _handleFlipStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    widget.onRevealed?.call();
  }

  void _handleFlipProgress() {
    if (_showsSentence || !mounted) return;
    // 앞면이 드러나기 시작하는 지점입니다(카드 뒤집기의 절반).
    if (_flipController.value < 0.5) return;
    setState(() => _showsSentence = true);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _flipController
      ..removeStatusListener(_handleFlipStatus)
      ..removeListener(_handleFlipProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final cardWidth = MafiaPhoneDesign.contentWidth * scale;
        final cardHeight = cardWidth / MafiaPhoneDesign.storedCardAspectRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            Positioned(
              left: MafiaPhoneDesign.left(size, MafiaPhoneDesign.contentLeft),
              top: MafiaPhoneDesign.top(size, _cardTop),
              width: cardWidth,
              height: cardHeight,
              child: _buildFlippingCard(scale),
            ),
            _buildSentence(),
            MafiaStoredRoleCard(role: widget.myRole),
          ],
        );
      },
    );
  }

  /// 뒤집히는 카드입니다.
  Widget _buildFlippingCard(double scale) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, _) {
        // 시작·끝을 눙치는 곡선으로 종이 카드처럼 부드럽게 돕니다(P1과 동일).
        final progress = Curves.easeInOutCubic.transform(_flipController.value);

        return MafiaFlipCard(
          progress: progress,
          front: widget.executedRole?.card,
          back: Assets.games.mafia.images.cards.roleBack.game,
          borderRadius: BorderRadius.circular(
            MafiaPhoneDesign.buttonRadius * scale,
          ),
          // 뒷면 위에 얹힌 대상의 원형 사진입니다. 뒤집기가 시작되면
          // 사라져, 앞면에 사진이 겹쳐 보이지 않게 합니다.
          backOverlay: _buildPortrait(scale, progress),
        );
      },
    );
  }

  Widget _buildPortrait(double scale, double progress) {
    // 뒤집기 전반부(0 → 0.5) 동안 서서히 사라집니다.
    final opacity = (1 - progress * 2).clamp(0.0, 1.0);
    if (opacity == 0) return const SizedBox.shrink();

    final portrait = _portraitSize * scale;
    // 카드 안쪽 좌표로 바꿉니다. 카드는 시안 top 208에서 시작합니다.
    final offsetTop = (_portraitTop - _cardTop) * scale;

    return Positioned(
      left: (MafiaPhoneDesign.openCardWidth * scale - portrait) / 2,
      top: offsetTop,
      width: portrait,
      height: portrait,
      child: Opacity(
        opacity: opacity,
        child: ClipOval(
          child: MafiaProfileImage(
            url: widget.executed.profileImageUrl,
            characterId: widget.executed.characterId,
          ),
        ),
      ),
    );
  }

  /// "○○님은 ○○이었습니다." 문구입니다.
  ///
  /// 카드가 절반 돌아간 순간 두 박자로 내려찍힙니다(확정 2026-08).
  Widget _buildSentence() {
    if (!_showsSentence) return const SizedBox.shrink();
    final role = widget.executedRole;

    return MafiaPhoneAnnouncement(
      beats: role == null
          ? MafiaCopy.unknownRoleBeats(widget.executed.nickname)
          : MafiaCopy.wasRoleBeats(widget.executed.nickname, role.displayName),
      top: _sentenceTop,
      sideMargin: 0,
      // 다음 단계로 넘어가기 전에 두 박자가 다 들어가게 줄였습니다.
      beatHold: _sentenceBeatHold,
    );
  }
}
