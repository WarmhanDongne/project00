// [phone_game_shell.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [GameFlow] : 게임의 공통 단계·안내·종료 흐름을 정의함
//
// 즉, 각 게임이 같은 화면 전환 규칙과 예외 처리를 공유하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/phone/animations/game_entry_unroll.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/phone_game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_auto_complete.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/shared/widgets/game_announcement_layer.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';

// ============================================================

/// 게임별 휴대폰 Stage가 공용 셸에서 어떤 역할을 하는지 알려 줍니다.
///
/// 각 게임은 `FinalCallPhoneStage`처럼 자세한 enum을 사용하고, 셸에는 이 역할만
/// 함께 넘깁니다. 따라서 셸이 게임별 서버 phase 문자열을 알 필요가 없습니다.
enum PhoneGameShellStageRole {
  connecting,
  intro,
  roundIntro,
  playing,
  result,
  closing;

  bool get showsTopBar =>
      this == PhoneGameShellStageRole.playing ||
      this == PhoneGameShellStageRole.result;
}

/// 휴대폰 게임 화면의 공통 골격입니다.
///
/// 게임마다 매번 다시 짜다가 어긋났던 부분(진입 연출 순서, 상단바 등장 타이밍,
/// 퇴장 버튼이 사라지는 상태)을 한곳에서 처리합니다. 각 게임은 [stage] 계산과
/// 자기 화면(topBar/content/result)만 넘기면 됩니다.
///
/// 처리 범위:
/// - 진입 매트 연출([GameEntryUnroll])
/// - `GAME START` / `ROUND N` 문구 (연출 중에는 다른 UI를 모두 감춤)
/// - 상단바 등장 연출([ControlEntryAnimation]) 및 **퇴장 접근 보장**
/// - 결과 화면과 종료 안내
class PhoneGameShell<TStage extends Enum> extends StatefulWidget {
  const PhoneGameShell({
    super.key,
    required this.stage,
    required this.stageRole,
    required this.flowConfig,
    required this.roundNumber,
    required this.background,
    required this.content,
    required this.onIntroCompleted,
    required this.onRoundIntroCompleted,
    this.topBar,
    this.result,
    this.closingMessage = GameFlowCopy.insufficientPlayers,
    this.introTextColor = Colors.white,
    this.announcementStyle,
    this.contentReady = true,
    this.contentRevealed = true,
    this.onConnectingExit,
  });

  /// 현재 화면 단계입니다. 게임의 서버 상태를 번역해 넘깁니다.
  final TStage stage;

  /// 현재 게임별 Stage가 공용 셸에서 담당하는 역할입니다.
  final PhoneGameShellStageRole stageRole;
  final int roundNumber;

  /// 게임 배경입니다. 연출·대기 화면에서도 같은 배경을 씁니다.
  final Widget background;

  /// 실제 게임 진행 화면입니다.
  final Widget content;

  /// 상단바입니다. 표시 시점과 등장 연출은 셸이 제어합니다.
  final Widget? topBar;

  /// 승자 결과 화면입니다.
  final Widget? result;

  final String closingMessage;
  final Color introTextColor;
  final GameAnnouncementStyle? announcementStyle;

  /// 문구·연출·입력 차단 의도를 모아 둔 화면 단계 설정입니다.
  ///
  /// null이면 [buildPhoneGameFlowConfig]의 공용 기본값을 사용합니다. 게임별로
  /// 시간을 바꿀 때 셸 내부 타이머를 수정하지 말고 이 설정을 교체하세요.
  final GameFlowConfig<TStage> flowConfig;

  /// 진행 화면을 그릴 준비가 됐는지 여부입니다. false면 배경만 보여 줍니다.
  final bool contentReady;

  /// 손패 공개(펼치기) 연출까지 끝났는지 여부입니다.
  ///
  /// 펼치는 도중에 상단바가 먼저 나타나면 연출이 깨지므로, 공개가 끝난 뒤에
  /// 상단바를 등장시킵니다. 공개 단계가 없는 게임은 기본값(true)을 씁니다.
  final bool contentRevealed;

  final VoidCallback onIntroCompleted;
  final VoidCallback onRoundIntroCompleted;

  /// 연결 단계가 비정상적으로 길어질 때 표시하는 나가기 버튼의 동작입니다.
  ///
  /// 연결 단계는 배경만 보여 주는 것이 기본 연출이지만, 서버 상태가 오래
  /// 오지 않으면 대기 안내와 탈출 수단을 제공해 영구 대기를 막습니다.
  final VoidCallback? onConnectingExit;

  @override
  State<PhoneGameShell<TStage>> createState() => _PhoneGameShellState<TStage>();
}

class _PhoneGameShellState<TStage extends Enum>
    extends State<PhoneGameShell<TStage>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  bool _hasShownTopBar = false;
  int _entrySyncGeneration = 0;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: PhoneGameFlowTiming.controlsEntry,
    );
    if (_shouldShowTopBar) {
      _entryController.value = 1;
      _hasShownTopBar = true;
    }
  }

  bool get _shouldShowTopBar =>
      (_flowStep.phoneRegions?.showTopBar ?? widget.stageRole.showsTopBar) &&
      widget.contentRevealed;

  @override
  void didUpdateWidget(PhoneGameShell<TStage> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntry();
  }

  /// 상단바가 처음 보이는 시점에 한 번만 등장 연출을 재생합니다.
  ///
  /// 컨트롤러를 build 도중에 되돌리면 리스너가 즉시 setState를 호출해 오류가
  /// 나므로 프레임이 끝난 뒤에 처리합니다.
  void _syncEntry() {
    final shouldShow = _shouldShowTopBar;
    if (shouldShow && !_hasShownTopBar) {
      _hasShownTopBar = true;
      final generation = ++_entrySyncGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _entrySyncGeneration &&
            _hasShownTopBar &&
            _shouldShowTopBar) {
          _entryController.forward();
        }
      });
    } else if (!shouldShow && _hasShownTopBar) {
      // 다음 라운드 안내·재배분이 시작되면 다시 감췄다가 등장시킵니다.
      _hasShownTopBar = false;
      final generation = ++_entrySyncGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _entrySyncGeneration &&
            !_hasShownTopBar &&
            !_shouldShowTopBar) {
          _entryController.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _entrySyncGeneration += 1;
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowStep = _flowStep;
    final announcement = flowStep.buildAnnouncement();
    return GameEntryUnroll(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            widget.background,
            ...switch (widget.stageRole) {
              // 결과 단계만 진행 화면을 결과 화면으로 **교체**합니다.
              PhoneGameShellStageRole.result =>
                flowStep.showScreen
                    ? [
                        if (widget.result != null) widget.result!,
                        ..._buildTopBar(),
                      ]
                    : const <Widget>[],
              // 나머지 단계는 전부 같은 진행 화면을 유지합니다. `showScreen`이
              // false인 단계에서도 **비우지 않고 가립니다** — 자식을 목록에서
              // 빼면 그 아래 State가 함께 사라져, 라운드마다 손패와 진행 중인
              // 애니메이션이 새로 만들어집니다.
              _ => _buildPlaying(flowStep),
            },
            // 문구 슬롯은 phase가 바뀌어도 항상 같은 자리에 유지합니다.
            Positioned.fill(
              child: GameAnnouncementLayer(
                announcement: announcement,
                style: _announcementStyleForPhase(),
                onCompleted: _handleAnnouncementCompleted,
              ),
            ),
            // 문구 OFF여도 시작/라운드의 로컬 완료 콜백은 필요합니다.
            // null 문구는 onCompleted를 내지 않으므로 이 경로가 없으면
            // board에서 안내를 끈 순간 intro 단계에 영구 대기하게 됩니다.
            if (announcement == null &&
                (widget.stageRole == PhoneGameShellStageRole.intro ||
                    widget.stageRole == PhoneGameShellStageRole.roundIntro))
              GameFlowAutoComplete(
                key: ValueKey(
                  'hidden-intro-${widget.stage}-${widget.roundNumber}',
                ),
                delay: flowStep.beforeDelay + flowStep.afterDelay,
                onCompleted: widget.stageRole == PhoneGameShellStageRole.intro
                    ? widget.onIntroCompleted
                    : widget.onRoundIntroCompleted,
              ),
            // 연결 단계가 길어지면 배경만 남는 화면 대신 대기 안내를 표시합니다.
            GameConnectingOverlay(
              isWaiting: widget.stageRole == PhoneGameShellStageRole.connecting,
              onExit: widget.onConnectingExit,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlaying(GameFlowStep<TStage> flowStep) => [
    // [contentReady]는 "아직 그릴 데이터가 없다"는 뜻이라 **만들지 않습니다**.
    // 반면 [GameFlowStep.showScreen]이 false인 것은 "지금은 보이면 안 된다"는
    // 뜻이라 **만들어 두고 가립니다**. 둘을 같게 다루면 연출 단계마다 화면이
    // 통째로 다시 만들어집니다.
    if (widget.contentReady)
      Offstage(
        offstage: !flowStep.showScreen,
        child: AbsorbPointer(
          // 안내 레이어는 항상 포인터를 통과시킵니다. 단계 자체가 입력을
          // 막아야 할 때만 셸이 실제 게임 content를 차단합니다.
          absorbing: flowStep.blocksInteraction,
          child: widget.content,
        ),
      ),
    ..._buildTopBar(),
  ];

  /// 상단바는 진행·결과 단계에서 항상 그립니다. 손패가 비어 화면이 빈
  /// 순간에도 퇴장할 수 있어야 하기 때문입니다.
  List<Widget> _buildTopBar() {
    final topBar = widget.topBar;
    if (topBar == null || !_shouldShowTopBar) return const [];
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: ControlEntryAnimation(
            animation: _entryController,
            style: ControlEntryStyle.header,
            begin: 0,
            end: 0.76,
            child: topBar,
          ),
        ),
      ),
    ];
  }

  GameFlowStep<TStage> get _flowStep => widget.flowConfig.stepFor(widget.stage);

  GameAnnouncementStyle _announcementStyleForPhase() {
    if (widget.stageRole == PhoneGameShellStageRole.closing) {
      return const GameAnnouncementStyle(
        fontFamily: null,
        fontSize: 22,
        gameStartFontSize: 58,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        shadows: [Shadow(color: Colors.black, blurRadius: 12)],
      );
    }
    return widget.announcementStyle ??
        GameAnnouncementStyle.phone(textColor: widget.introTextColor);
  }

  void _handleAnnouncementCompleted(GameAnnouncement announcement) {
    switch (announcement.kind) {
      case GameAnnouncementKind.gameStart:
        widget.onIntroCompleted();
      case GameAnnouncementKind.round:
        widget.onRoundIntroCompleted();
      case GameAnnouncementKind.transient:
      case GameAnnouncementKind.persistent:
        break;
    }
  }
}
