import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/mafia_flip_card.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/gen/assets.gen.dart';

/// 처형자 발표 화면의 좌표입니다.
///
/// 확정(2026-08): 제목은 다른 단계 화면의 안내 문구와 **같은 자리·크기**를
/// 씁니다([MafiaPhoneStatusText]). 예전에는 제목만 36px에 168/218이라 단계가
/// 바뀔 때 글자 크기가 튀어 보였습니다.
@immutable
class _ResultLayout {
  const _ResultLayout({
    required this.portraitTop,
    required this.nicknameWeight,
  });

  final double portraitTop;

  /// 닉네임 굵기입니다. 시안이 당사자는 Light, 나머지는 Regular로 그렸습니다.
  final FontWeight nicknameWeight;

  /// 제목은 다른 화면의 안내 문구와 같은 자리입니다.
  double get titleTop => MafiaPhoneStatusText.promptTop;

  /// 닉네임은 두 시안 모두 사진 아래 10px에 있습니다.
  double get nicknameTop => portraitTop + _portraitSize + 10;

  static const double _portraitSize = 178;

  /// 당사자용입니다. 아래 문구가 없어 사진 묶음만 띠 가운데에 옵니다.
  static const _ResultLayout self = _ResultLayout(
    portraitTop: 288,
    nicknameWeight: FontWeight.w300,
  );

  /// 나머지 사람용입니다. 아래에 "○○님이 처형되었습니다." 문구가 붙습니다.
  ///
  /// 사진·닉네임·아래 문구를 합한 묶음이 내용 띠 가운데에 오는 자리입니다.
  static const _ResultLayout other = _ResultLayout(
    portraitTop: 300,
    nicknameWeight: FontWeight.w400,
  );
}

//=======================P7 처형자 발표==============================
/// 투표 결과로 처형된 사람을 알리는 화면입니다.
///
/// 시안 두 장이 이 위젯 하나입니다. 처형된 사람이 나인지에 따라 갈립니다.
///
/// | 시안 | 조건 | 제목 | 아래 문구 |
/// |---|---|---|---|
/// | `투표 결과발표` | 남이 처형됨 | 오늘의 처형자 | ○○님이 처형되었습니다. |
/// | `투표 결과 당사자` | [isMe] | 당신은 처형 당했습니다 | 없음 |
///
/// 당사자 시안은 아래 문구가 없어 제목·사진이 위로 올라가 있습니다. 두 시안 모두
/// 닉네임은 사진 아래 10px입니다.
///
/// 처형된 사람이 **누구인지만** 보여 줍니다. 신분 공개는 다음 화면
/// ([MafiaExecutionRevealView])에서 카드를 뒤집어 보여 줍니다.
class MafiaExecutionResultView extends StatelessWidget {
  const MafiaExecutionResultView({
    super.key,
    required this.role,
    required this.executed,
    this.isMe = false,
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다.
  final MafiaRole? role;

  /// 처형된 사람입니다. null이면 아무도 처형되지 않은 것으로 보고
  /// 그 사실을 문구로 알립니다(동표가 무효 처리되는 규칙일 때).
  final MafiaPlayer? executed;

  /// 처형된 사람이 나인지입니다. true면 당사자용 시안으로 그립니다.
  final bool isMe;

  //=======================시안 기준 좌표==============================
  static const double _portraitSize = 178;
  static const double _sentenceTop = 674;

  /// 아무도 처형되지 않았을 때의 문구 자리입니다(아침 발표와 같은 높이).
  static const double _noExecutionTop = MafiaPhoneStatusText.announcementTop;

  /// 시안이 문구에 남겨 둔 좌우 여백입니다(당사자 시안의 제목 묶음 기준).
  static const double _sideMargin = 27;

  @override
  Widget build(BuildContext context) {
    // 아무도 처형되지 않았으면 당사자도 없으므로 나머지 사람용 배치를 씁니다.
    final layout = (isMe && executed != null)
        ? _ResultLayout.self
        : _ResultLayout.other;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final target = executed;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            // 남이 처형된 시안 문구는 '오늘 의 처형자'이지만 띄어쓰기가 어긋난
            // 것으로 보고 바로잡았습니다.
            // 확정(2026-08): 안내 문구는 내려찍습니다([MafiaPhoneAnnouncement]).
            MafiaPhoneAnnouncement(
              beats: [
                layout == _ResultLayout.self
                    ? MafiaCopy.executedSelfTitle
                    : MafiaCopy.executedOtherTitle,
              ],
              top: layout.titleTop,
            ),
            if (target == null)
              // 아침 발표(사망자 없음)와 같은 자리·크기로 알립니다.
              const MafiaPhoneAnnouncement(
                beats: [MafiaCopy.noExecution],
                top: _noExecutionTop,
                fontSize: MafiaPhoneStatusText.waitingFontSize,
              )
            else ...[
              Positioned(
                left: (size.width - _portraitSize * scale) / 2,
                top: MafiaPhoneDesign.top(size, layout.portraitTop),
                width: _portraitSize * scale,
                height: _portraitSize * scale,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * scale),
                    child: MafiaProfileImage(url: target.profileImageUrl),
                  ),
                ),
              ),
              _buildCenteredText(
                size,
                top: layout.nicknameTop,
                text: target.nickname,
                fontSize: 32,
                scale: scale,
                fontWeight: layout.nicknameWeight,
              ),
              // 당사자 시안에는 이 문구가 없습니다. 자기가 처형된 것을 제목에서
              // 이미 알렸으므로 같은 말을 두 번 하지 않습니다.
              if (layout == _ResultLayout.other)
                MafiaPhoneAnnouncement(
                  beats: MafiaCopy.executedBeats(target.nickname),
                  top: _sentenceTop,
                ),
            ],
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }

  Widget _buildCenteredText(
    Size size, {
    required double top,
    required String text,
    required double fontSize,
    required double scale,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    // 시안이 문구에 남겨 둔 좌우 여백입니다. 닉네임이 길어도 글자가 화면
    // 끝에 닿지 않게 이 안에서만 줄여 담습니다.
    final margin = MafiaPhoneDesign.left(size, _sideMargin);

    return Positioned(
      left: margin,
      right: margin,
      top: MafiaPhoneDesign.top(size, top),
      child: IgnorePointer(
        // 시안은 한 줄입니다. 닉네임이 길어도 줄이 늘지 않게 눌러 담습니다.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize * scale,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}

//=======================P7 처형자 신분 공개==============================
/// 처형된 사람의 신분을 카드를 뒤집어 공개하는 화면입니다.
///
/// 시안 두 장이 한 연출의 앞뒤입니다.
///
/// | 시안 | 상태 |
/// |---|---|
/// | `투표 결과 신분공개` (뒤집기 전) | 뒷면 카드 + 대상의 원형 사진 |
/// | `투표 결과 신분공개` (뒤집은 후) | 앞면 카드 + "○○님은 ○○이었습니다." |
///
/// 역할 이름으로 분기하지 않고 [MafiaRole]의 값만 읽으므로, 새 신분을
/// 추가해도 이 화면은 수정할 필요가 없습니다. 카드 앞면 에셋이 아직 없는
/// 역할은 뒷면을 유지하고 문구로 신분을 알립니다.
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

  //=======================연출 시간==============================
  /// 화면이 뜨고 카드를 뒤집기까지 기다리는 시간입니다.
  static const Duration revealDelay = Duration(milliseconds: 600);

  /// 카드가 뒤집히는 시간입니다. P1 역할 확인과 같게 맞췄습니다.
  static const Duration flipDuration = Duration(milliseconds: 620);

  @override
  State<MafiaExecutionRevealView> createState() =>
      _MafiaExecutionRevealViewState();
}

class _MafiaExecutionRevealViewState extends State<MafiaExecutionRevealView>
    with SingleTickerProviderStateMixin {
  //=======================시안 기준 좌표==============================
  // 시안은 뒤집기 전 카드가 top 208, 뒤집은 후가 top 217로 9px 어긋나 있습니다.
  // 같은 카드가 튀어 보이지 않게 208로 통일했습니다.
  static const double _cardTop = 208;
  static const double _portraitTop = 355;
  static const double _portraitSize = 116;
  static const double _sentenceTop = 666;

  /// 신분 문구의 첫 박자가 머무는 시간입니다.
  static const Duration _sentenceBeatHold = Duration(milliseconds: 1200);

  late final AnimationController _flipController;
  Timer? _startTimer;

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
    _startTimer = Timer(MafiaExecutionRevealView.revealDelay, () {
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
      left: (MafiaPhoneDesign.contentWidth * scale - portrait) / 2,
      top: offsetTop,
      width: portrait,
      height: portrait,
      child: Opacity(
        opacity: opacity,
        child: ClipOval(
          child: MafiaProfileImage(url: widget.executed.profileImageUrl),
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
