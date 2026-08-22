import 'package:flutter/material.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
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
/// | 투표권 없음 | [voteBanned] | 그리드 없이 안내 문구만(마담에게 유혹당함) |
///
/// 밤 지목(P2~P4)과 **좌표가 완전히 같습니다.** 다른 점은 배경이 밝아 글자가
/// 검은색이고, 대상을 고르면 나머지가 흐려지는 것뿐입니다. 그래서 그리드는
/// [MafiaPlayerSelectGrid]를 그대로 쓰고 색만 바꿉니다.
///
/// 투표는 모두가 함께 하는 단계라, 새 신분이 추가돼도 이 화면은 고칠 필요가
/// 없습니다. 역할에 따라 달라지는 것은 아래 보관 카드뿐입니다.
class MafiaVoteView extends StatefulWidget {
  const MafiaVoteView({
    super.key,
    required this.role,
    this.players = const [],
    this.selectedUid,
    this.remainingSeconds,
    this.isSubmitted = false,
    this.voteBanned = false,
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

  /// 이번 낮에 투표할 수 없는지입니다(마담에게 유혹당함).
  ///
  /// 고를 수 없는 그리드를 보여 주면 막힌 화면이 되므로, 이유를 적은 안내
  /// 문구만 그립니다. 이 사실은 본인만 알 수 있어(private) 신분이 새지 않습니다.
  final bool voteBanned;

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

  //=======================제출 연출==============================
  /// 표를 내는 연출의 전체 시간입니다(확정 2026-08).
  ///
  ///   가운데 요소가 뭉쳐 사라짐 → 투표지 한 장으로 바뀜 → 위로 날아감
  static const Duration submitDuration = Duration(milliseconds: 900);

  /// 투표지 크기입니다(시안 기준). 태블릿 투표지와 같은 46 : 34 비율입니다.
  static const double paperWidth = 120;
  static const double paperHeight = paperWidth * 34 / 46;

  @override
  State<MafiaVoteView> createState() => _MafiaVoteViewState();
}

class _MafiaVoteViewState extends State<MafiaVoteView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _submit;

  /// 내가 눌러서 연출이 돌아가는 중인지입니다.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _submit = AnimationController(
      vsync: this,
      duration: MafiaVoteView.submitDuration,
    )..addStatusListener(_handleSubmitDone);
  }

  void _handleSubmitDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // 연출이 끝나면 대기 화면으로 넘깁니다. 서버 응답이 늦어도 화면은
    // 먼저 넘어가 있어야 두 번 누르지 않습니다.
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _submit
      ..removeStatusListener(_handleSubmitDone)
      ..dispose();
    super.dispose();
  }

  /// 표를 냅니다. 연출을 시작하면서 서버에도 바로 보냅니다.
  void _handleConfirm() {
    final confirm = widget.onConfirm;
    if (confirm == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    _submit.forward(from: 0);
    confirm();
  }

  //=======================연출 구간==============================
  /// 가운데 요소가 뭉쳐 사라지는 진행도입니다.
  double get _collapse =>
      Curves.easeIn.transform((_submit.value / 0.45).clamp(0.0, 1.0));

  /// 투표지가 나타나는 진행도입니다.
  double get _paperIn =>
      Curves.easeOut.transform(((_submit.value - 0.3) / 0.25).clamp(0.0, 1.0));

  /// 투표지가 위로 날아가는 진행도입니다.
  double get _flyAway =>
      Curves.easeIn.transform(((_submit.value - 0.55) / 0.45).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        // 연출 중에는 서버 상태와 무관하게 연출 화면을 보여 줍니다.
        final showsWaiting = !_isSubmitting && widget.isSubmitted;
        final showsBanned =
            !_isSubmitting && !showsWaiting && widget.voteBanned;

        // 제출 연출이 매 프레임 다시 그려지도록 컨트롤러를 구독합니다.
        return AnimatedBuilder(
          animation: _submit,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: MafiaPhoneBackground.day()),
              if (showsBanned)
                _buildBanned(size, scale)
              else if (showsWaiting)
                _buildWaiting(size, scale)
              else if (_isSubmitting)
                ..._buildSubmitAnimation(size, scale)
              else
                ..._buildSelectionLayer(size, scale),
              MafiaStoredRoleCard(role: widget.role),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSelectionLayer(Size size, double scale) {
    return [
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, MafiaVoteView._promptTop),
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
      if (widget.remainingSeconds != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, MafiaVoteView._timerTop),
          child: IgnorePointer(
            child: Text(
              '${widget.remainingSeconds}초',
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
        top: MafiaPhoneDesign.top(
          size,
          MafiaPlayerSelectGrid.topFor(widget.players.length),
        ),
        child: MafiaPlayerSelectGrid(
          players: widget.players,
          selectedUid: widget.selectedUid,
          selectionColor: MafiaVoteView.selectionColor,
          // 시안의 낮 투표는 테두리 3px, 나머지는 40%로 흐립니다.
          selectionBorderWidth: 3,
          nicknameColor: Colors.black,
          dimsUnselected: true,
          onSelect: widget.onSelect,
        ),
      ),
      MafiaPhoneActionButton(
        label: '선택 완료',
        onTap: _handleConfirm,
        enabled: widget.selectedUid != null && widget.onConfirm != null,
        // 확정(2026-08): 아무도 고르지 않았으면 버튼을 **보이지 않게** 둡니다.
        hiddenWhenDisabled: true,
      ),
    ];
  }

  //=======================제출 연출==============================
  /// 가운데 요소가 뭉쳐 사라지고, 투표지 한 장이 되어 위로 날아갑니다.
  ///
  /// 확정(2026-08): 태블릿에서 쓰는 그 투표지([MafiaBallotPaper])로 바뀌어
  /// 화면 위로 빠져나갑니다. 내 표가 태블릿의 투표함으로 간다는 것을 두 화면이
  /// 같은 종이로 이어 보여 줍니다.
  List<Widget> _buildSubmitAnimation(Size size, double scale) {
    return [
      // 1. 안내·타이머·격자가 가운데로 뭉쳐 사라집니다.
      Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: (1 - _collapse).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - 0.8 * _collapse,
              // 내용 띠 가운데로 모입니다.
              alignment: Alignment(
                0,
                (MafiaPhoneDesign.contentBandCenter /
                            MafiaPhoneDesign.size.height) *
                        2 -
                    1,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: _buildSelectionLayer(size, scale),
              ),
            ),
          ),
        ),
      ),
      // 2. 그 자리에 투표지가 생겨 3. 위로 날아갑니다.
      if (_paperIn > 0) _buildFlyingPaper(size, scale),
    ];
  }

  Widget _buildFlyingPaper(Size size, double scale) {
    final width = MafiaVoteView.paperWidth * scale;
    final height = MafiaVoteView.paperHeight * scale;
    final centerTop = MafiaPhoneDesign.top(
      size,
      MafiaPhoneDesign.contentBandCenter,
    );
    // 화면 위로 완전히 빠져나갈 만큼 올립니다.
    final travel = (centerTop + height) * _flyAway;

    return Positioned(
      left: (size.width - width) / 2,
      top: centerTop - height / 2 - travel,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: _paperIn,
          child: Transform.rotate(
            // 날아가며 살짝 기울어집니다.
            angle: -0.12 * _flyAway,
            child: Transform.scale(
              scale: 0.6 + 0.4 * _paperIn,
              child: MafiaBallotPaper(width: width, height: height),
            ),
          ),
        ),
      ),
    );
  }

  /// 표를 내고 다른 사람을 기다리는 화면입니다.
  ///
  /// 투표권을 잃은 사람에게 이유를 알려 줍니다(마담에게 유혹당함).
  ///
  /// 대기 문구와 같은 자리를 씁니다. 다른 사람 화면과 겉모습이 같아야 이 사람이
  /// 무엇을 당했는지 옆에서 보고 알 수 없습니다.
  Widget _buildBanned(Size size, double scale) {
    return Positioned(
      left: 0,
      right: 0,
      top: MafiaPhoneDesign.top(size, MafiaVoteView._waitingTop),
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '이번 낮에는\n투표할 수 없습니다',
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

  /// 그리드·타이머·버튼을 모두 지웁니다. 표를 낸 뒤에는 바꿀 수 없다는 것을
  /// 화면으로 알려 주는 편이 분명합니다.
  Widget _buildWaiting(Size size, double scale) {
    return Positioned(
      left: 0,
      right: 0,
      top: MafiaPhoneDesign.top(size, MafiaVoteView._waitingTop),
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
