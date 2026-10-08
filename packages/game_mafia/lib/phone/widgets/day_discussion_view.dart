// [day_discussion_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/game_theme.dart';

// ============================================================

// ---------------------------------------------------------------------------
// P6 낮 자유 토론 화면
// ---------------------------------------------------------------------------
/// 낮 자유 토론 화면입니다. 시안 P6의 두 상태가 모두 이 위젯 하나입니다.
///
/// | 시안 | 조건 | 차이 |
/// |---|---|---|
/// | P6 기본 | 남은 시간이 넉넉함 | 타이머가 검은색 |
/// | P6 시간 없을때 | 남은 시간이 [urgentThreshold] 미만 | 타이머가 빨간색 |
///
/// 밤 화면과 달리 배경이 밝아 글자가 **검은색**입니다.
///
/// 역할에 따라 달라지는 것은 아래 보관 카드뿐입니다. 토론은 모두가 함께 하는
/// 단계라, 새 신분이 추가돼도 이 화면은 고칠 필요가 없습니다.
class MafiaDayDiscussionView extends StatelessWidget {
  const MafiaDayDiscussionView({
    super.key,
    required this.role,
    this.title = '토론',
    this.remainingSeconds,
    this.onEndDiscussion,
    this.canEndDiscussion = false,
    this.skipVoteCount = 0,
    this.aliveCount = 0,
    this.hasVotedToSkip = false,
    this.endLabel = '토론 끝내기 동의',
    this.endedByVote = false,
    this.alivePlayers = const [],
    this.lastNightDead = const [],
  });

  final MafiaRole? role;

  /// 타이머 위 작은 꼬리표입니다(시안: `토론`).
  final String title;
  final int? remainingSeconds;
  final VoidCallback? onEndDiscussion;
  final bool canEndDiscussion;
  final int skipVoteCount;
  final int aliveCount;
  final bool hasVotedToSkip;
  final String endLabel;

  /// 과반수가 동의해 토론이 끝났는지입니다. 안내만 남기고 곧 투표로 넘어갑니다.
  final bool endedByVote;

  /// 살아 있는 사람입니다(시안: `생존 5` 얼굴 줄).
  final List<MafiaPlayer> alivePlayers;

  /// 어젯밤 쓰러진 사람입니다(시안: 위쪽 소식 포스터).
  final List<MafiaPlayer> lastNightDead;

  static const double _newsTop = 92;
  static const double _timerTop = 264;
  static const double _aliveLabelTop = 476;
  static const double _aliveTop = 498;

  /// 남은 시간이 이보다 적으면 타이머를 빨갛게 칠합니다.
  static const int urgentThreshold = 30;

  /// 남은 시간을 `2:30`처럼 적습니다.
  static String formatRemaining(int seconds) => mafiaNoirClock(seconds);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final seconds = endedByVote ? null : remainingSeconds;
        final frameWidth = 340 * scale;
        final faceSize = alivePlayers.length > 6 ? 40.0 : 52.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            // 어젯밤 소식 — 쓰러진 사람의 얼굴과 비스듬한 검은 띠입니다.
            Positioned(
              left: (size.width - frameWidth) / 2,
              top: MafiaPhoneDesign.top(size, _newsTop),
              width: frameWidth,
              height: 150 * scale,
              child: IgnorePointer(
                child: _LastNightNews(dead: lastNightDead, scale: scale),
              ),
            ),
            // 토론 타이머 액자
            Positioned(
              left: (size.width - frameWidth) / 2,
              top: MafiaPhoneDesign.top(size, _timerTop),
              width: frameWidth,
              height: 190 * scale,
              child: IgnorePointer(
                child: MafiaNoirFrame(
                  inset: 6 * scale + 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        endedByVote ? '토론 종료' : title,
                        style: mafiaNoirBody(
                          14 * scale,
                          color: MafiaColors.noirBrass,
                          letterSpacing: 5.6 * scale,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          seconds == null
                              ? MafiaCopy.discussionSkippedNotice
                              : formatRemaining(seconds),
                          maxLines: 1,
                          style: mafiaNoirDisplay(
                            (seconds == null ? 26 : 100) * scale,
                            height: 1,
                            color: seconds != null && seconds < urgentThreshold
                                ? MafiaColors.noirRose
                                : MafiaColors.noirPaper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (alivePlayers.isNotEmpty) ...[
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, _aliveLabelTop),
                child: Text(
                  '생존 ${alivePlayers.length}',
                  textAlign: TextAlign.center,
                  style: mafiaNoirBody(
                    13 * scale,
                    color: MafiaColors.noirUmber,
                    letterSpacing: 4 * scale,
                  ),
                ),
              ),
              Positioned(
                left: MafiaPhoneDesign.left(size, 20),
                right: MafiaPhoneDesign.left(size, 20),
                top: MafiaPhoneDesign.top(size, _aliveTop),
                child: IgnorePointer(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8 * scale,
                    runSpacing: 8 * scale,
                    children: [
                      for (final player in alivePlayers)
                        MafiaNoirFaceTile(
                          player: player,
                          size: faceSize * scale,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (!endedByVote)
              MafiaPhoneActionButton(
                label: hasVotedToSkip ? '동의했습니다' : endLabel,
                trailing: '$skipVoteCount / $aliveCount',
                backgroundColor: hasVotedToSkip
                    ? MafiaColors.noirBrass
                    : MafiaColors.noirInk,
                labelColor: hasVotedToSkip
                    ? MafiaColors.noirInk
                    : MafiaColors.noirPaper,
                outlineColor: MafiaColors.noirInk,
                onTap: onEndDiscussion,
                enabled:
                    canEndDiscussion &&
                    !hasVotedToSkip &&
                    onEndDiscussion != null,
              ),
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }
}

/// 낮 화면 위쪽의 어젯밤 소식입니다.
class _LastNightNews extends StatelessWidget {
  const _LastNightNews({required this.dead, required this.scale});

  final List<MafiaPlayer> dead;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final first = dead.firstOrNull;
    final headline = first == null
        ? '어젯밤은 조용히 지나갔다'
        : '어젯밤, ${mafiaJosa(dead.map((player) => player.nickname).join(' · '), '이', '가')} 쓰러졌다';
    return Stack(
      children: [
        Positioned(
          left: 20 * scale,
          top: 0,
          width: 120 * scale,
          height: 120 * scale,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: MafiaColors.noirTeal,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (first != null)
          Positioned(
            left: 24 * scale,
            top: 4 * scale,
            width: 112 * scale,
            height: 112 * scale,
            child: MafiaNoirFace(player: first, grayscale: true),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 70 * scale,
          child: ClipPath(
            clipper: const _NewsSlant(),
            child: ColoredBox(
              color: MafiaColors.noirInk,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    0,
                    16 * scale,
                    12 * scale,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      headline,
                      maxLines: 1,
                      style: mafiaNoirDisplay(24 * scale),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsSlant extends CustomClipper<Path> {
  const _NewsSlant();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * 0.36)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_NewsSlant oldClipper) => false;
}
