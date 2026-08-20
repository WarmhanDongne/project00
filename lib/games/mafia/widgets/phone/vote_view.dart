import 'package:flutter/material.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';

//=======================P7 낮 투표 화면==============================
/// 낮 투표 화면입니다. 시안 P7의 투표 단계 세 상태가 이 위젯 하나입니다.
///
/// | 시안 | 조건 | 화면 |
/// |---|---|---|
/// | 투표 전 | 고른 대상 없음 | 9칸 모두 선명, `선택 완료` 비활성 |
/// | 대상 선택 | [selectedUid] 있음 | 고른 칸만 선명 + 금색 테두리, 버튼 활성 |
/// | 제출 완료 | [isSubmitted] | 그리드·타이머 없이 대기 문구만 |
///
/// 밤 지목(P2~P4)과 **좌표가 완전히 같습니다.** 다른 점은 배경이 밝아 글자가
/// 검은색이고, 대상을 고르면 나머지가 흐려지는 것뿐입니다. 그래서 그리드는
/// [MafiaPlayerSelectGrid]를 그대로 쓰고 색만 바꿉니다.
///
/// 투표는 모두가 함께 하는 단계라, 새 신분이 추가돼도 이 화면은 고칠 필요가
/// 없습니다. 역할에 따라 달라지는 것은 아래 보관 카드뿐입니다.
class MafiaVoteView extends StatelessWidget {
  const MafiaVoteView({
    super.key,
    required this.role,
    this.players = const [],
    this.selectedUid,
    this.remainingSeconds,
    this.isSubmitted = false,
    this.onSelect,
    this.onConfirm,
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다.
  final MafiaRole? role;

  /// 투표할 수 있는 대상입니다. 호출부가 생존자만 걸러 전달합니다.
  final List<MafiaPlayer> players;

  final String? selectedUid;

  /// 남은 시간(초)입니다. null이면 타이머를 그리지 않습니다.
  final int? remainingSeconds;

  /// 표를 서버에 보냈는지입니다. true면 대기 화면이 됩니다.
  final bool isSubmitted;

  final ValueChanged<String>? onSelect;
  final VoidCallback? onConfirm;

  //=======================시안 기준 좌표==============================
  // 안내·타이머는 모든 단계 공통 자리(MafiaPhoneStatusText)를 씁니다.
  static const double _promptTop = MafiaPhoneStatusText.promptTop;
  static const double _timerTop = MafiaPhoneStatusText.timerTop;
  // 대기 문구도 밤(P5)과 같은 자리를 씁니다(2026-08 통일 지시. 시안은 360).
  static const double _waitingTop = MafiaPhoneStatusText.waitingTop;

  /// 낮 투표의 선택 테두리 색입니다(시안 `#B18D56`).
  ///
  /// 밤 행동과 달리 역할별로 색이 갈리지 않습니다. 투표는 모두가 같은 행동을
  /// 하기 때문입니다.
  static const Color selectionColor = Color(0xFFB18D56);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            if (isSubmitted)
              _buildWaiting(size, scale)
            else
              ..._buildSelectionLayer(size, scale),
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }

  List<Widget> _buildSelectionLayer(Size size, double scale) {
    return [
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _promptTop),
        child: IgnorePointer(
          child: Text(
            '투표 할 대상을 선택하세요',
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
      if (remainingSeconds != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, _timerTop),
          child: IgnorePointer(
            child: Text(
              '$remainingSeconds초',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: MafiaPhoneStatusText.timerFontSize * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, MafiaPlayerSelectGrid.designTop),
        child: MafiaPlayerSelectGrid(
          players: players,
          selectedUid: selectedUid,
          selectionColor: selectionColor,
          // 시안의 낮 투표는 테두리 3px, 나머지는 40%로 흐립니다.
          selectionBorderWidth: 3,
          nicknameColor: Colors.black,
          dimsUnselected: true,
          onSelect: onSelect,
        ),
      ),
      MafiaPhoneActionButton(
        label: '선택 완료',
        onTap: onConfirm,
        enabled: selectedUid != null && onConfirm != null,
      ),
    ];
  }

  /// 표를 내고 다른 사람을 기다리는 화면입니다.
  ///
  /// 그리드·타이머·버튼을 모두 지웁니다. 표를 낸 뒤에는 바꿀 수 없다는 것을
  /// 화면으로 알려 주는 편이 분명합니다.
  Widget _buildWaiting(Size size, double scale) {
    return Positioned(
      left: 0,
      right: 0,
      top: MafiaPhoneDesign.top(size, _waitingTop),
      child: IgnorePointer(
        // 시안은 두 줄이고 각 줄이 한 줄로 유지됩니다. 좁은 기기에서 더 쪼개지지
        // 않게 필요한 만큼만 줄입니다.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '다른 플레이어의 투표를\n기다리는 중입니다…',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: MafiaPhoneStatusText.waitingFontSize * scale,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
