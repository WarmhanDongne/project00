import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================P6 낮 자유 토론 화면==============================
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
    this.title = '자유 토론',
    this.remainingSeconds,
    this.onEndDiscussion,
    this.canEndDiscussion = false,
    this.skipVoteCount = 0,
    this.aliveCount = 0,
    this.hasVotedToSkip = false,
    this.endLabel = '토론 종료 하기',
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다. null이면 뒷면을 그립니다.
  final MafiaRole? role;

  /// 단계 이름입니다. 아침 발표 등 다른 낮 단계에서도 이 화면을 재사용합니다.
  final String title;

  /// 남은 시간(초)입니다. null이면 타이머를 그리지 않습니다.
  final int? remainingSeconds;

  /// 토론을 미리 끝낼 때입니다. null이면 버튼이 비활성입니다.
  final VoidCallback? onEndDiscussion;

  /// 지금 토론 종료에 동의를 보탤 수 있는지입니다.
  final bool canEndDiscussion;

  /// 조기 종료에 동의한 인원수입니다(확정 규칙: 과반수 투표).
  final int skipVoteCount;

  /// 살아 있는 인원수입니다. 버튼의 분모가 됩니다.
  final int aliveCount;

  /// 내가 이미 동의를 눌렀는지입니다. 한 번 누르면 취소할 수 없습니다.
  final bool hasVotedToSkip;

  final String endLabel;

  //=======================시안 기준 좌표==============================
  // 제목·타이머는 다른 단계와 같은 자리·크기를 씁니다(2026-08 통일 지시.
  // 시안은 제목 48px@142, 타이머 209였습니다).
  static const double _titleTop = MafiaPhoneStatusText.promptTop;
  static const double _timerTop = MafiaPhoneStatusText.timerTop;
  static const double _illustrationTop = 244;
  static const double _illustrationSize = 349;

  /// 이 시간 미만이면 타이머를 빨간색으로 바꿉니다.
  ///
  /// 시안('시간 없을때')이 29초를 빨간색으로 보여 주므로 30초로 잡았습니다.
  static const int urgentThreshold = 30;

  /// 시안의 표기법입니다. 1분 이상은 `2m 30s`, 1분 미만은 `29s`입니다.
  static String formatRemaining(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final rest = safe % 60;
    return minutes > 0 ? '${minutes}m ${rest}s' : '${rest}s';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final seconds = remainingSeconds;
        final illustration = _illustrationSize * scale;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            //=======================단계 이름==============================
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, _titleTop),
              child: IgnorePointer(
                child: Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: MafiaPhoneStatusText.promptFontSize * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            //=======================남은 시간==============================
            if (seconds != null)
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, _timerTop),
                child: IgnorePointer(
                  child: Text(
                    formatRemaining(seconds),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // 시간이 임박하면 시안대로 빨간색으로 경고합니다.
                      color: seconds < urgentThreshold
                          ? const Color(0xFFFF0000)
                          : Colors.black,
                      fontSize: MafiaPhoneStatusText.timerFontSize * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            //=======================토론 삽화==============================
            Positioned(
              left: (size.width - illustration) / 2,
              top: MafiaPhoneDesign.top(size, _illustrationTop),
              width: illustration,
              height: illustration,
              child: IgnorePointer(
                child: Assets.games.mafia.images.other.talkPhone.game.image(
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            // 확정(2026-08): **내가 누르기 전까지는** 원래 문구를 그대로 두고,
            // 누른 뒤에는 빨간 `동의한 사람/살아 있는 사람` 집계로 바뀌며
            // 버튼이 비활성됩니다. 남이 누른 것 때문에 내 버튼 문구가 먼저
            // 바뀌면, 아직 눌러야 하는지 헷갈립니다.
            //
            // 집계는 비활성된 뒤에도 계속 올라갑니다. 과반수가 되는 순간
            // 서버가 투표로 넘깁니다.
            MafiaPhoneActionButton(
              label: hasVotedToSkip ? '$skipVoteCount/$aliveCount' : endLabel,
              labelColor: hasVotedToSkip ? const Color(0xFFFF0000) : null,
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
