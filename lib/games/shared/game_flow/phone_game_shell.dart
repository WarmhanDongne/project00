import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/game_entry_unroll.dart';
import 'package:project00/games/shared/animations/phone_control_entry_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';

/// 휴대폰 게임 화면의 공통 골격입니다.
///
/// 게임마다 매번 다시 짜다가 어긋났던 부분(진입 연출 순서, 상단바 등장 타이밍,
/// 퇴장 버튼이 사라지는 상태)을 한곳에서 처리합니다. 각 게임은 [phase] 계산과
/// 자기 화면(topBar/content/result)만 넘기면 됩니다.
///
/// 처리 범위:
/// - 진입 매트 연출([GameEntryUnroll])
/// - `GAME START` / `ROUND N` 문구 (연출 중에는 다른 UI를 모두 감춤)
/// - 상단바 등장 연출([PhoneControlEntryAnimation]) 및 **퇴장 접근 보장**
/// - 결과 화면과 종료 안내
class PhoneGameShell extends StatefulWidget {
  const PhoneGameShell({
    super.key,
    required this.phase,
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
    this.gameStartAnnouncementDuration = const Duration(milliseconds: 1700),
    this.roundAnnouncementDuration = const Duration(milliseconds: 1900),
    this.contentReady = true,
    this.contentRevealed = true,
  });

  /// 현재 화면 단계입니다. 게임의 서버 상태를 번역해 넘깁니다.
  final GameScreenPhase phase;
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
  final Duration gameStartAnnouncementDuration;
  final Duration roundAnnouncementDuration;

  /// 진행 화면을 그릴 준비가 됐는지 여부입니다. false면 배경만 보여 줍니다.
  final bool contentReady;

  /// 손패 공개(펼치기) 연출까지 끝났는지 여부입니다.
  ///
  /// 펼치는 도중에 상단바가 먼저 나타나면 연출이 깨지므로, 공개가 끝난 뒤에
  /// 상단바를 등장시킵니다. 공개 단계가 없는 게임은 기본값(true)을 씁니다.
  final bool contentRevealed;

  final VoidCallback onIntroCompleted;
  final VoidCallback onRoundIntroCompleted;

  @override
  State<PhoneGameShell> createState() => _PhoneGameShellState();
}

class _PhoneGameShellState extends State<PhoneGameShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  bool _hasShownTopBar = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    if (_shouldShowTopBar) {
      _entryController.value = 1;
      _hasShownTopBar = true;
    }
  }

  bool get _shouldShowTopBar =>
      widget.phase.showsTopBar && widget.contentRevealed;

  @override
  void didUpdateWidget(PhoneGameShell oldWidget) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entryController.forward();
      });
    } else if (!shouldShow && _hasShownTopBar) {
      // 다음 라운드 안내·재배분이 시작되면 다시 감췄다가 등장시킵니다.
      _hasShownTopBar = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entryController.reset();
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = _announcementForPhase();
    return GameEntryUnroll(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            widget.background,
            ...switch (widget.phase) {
              GameScreenPhase.connecting => const <Widget>[],
              GameScreenPhase.intro ||
              GameScreenPhase.roundIntro => const <Widget>[],
              GameScreenPhase.playing => _buildPlaying(),
              GameScreenPhase.result => [
                if (widget.result != null) widget.result!,
                ..._buildTopBar(),
              ],
              GameScreenPhase.closing => const <Widget>[],
            },
            // 문구 슬롯은 phase가 바뀌어도 항상 같은 자리에 유지합니다.
            Positioned.fill(
              child: GameAnnouncementLayer(
                announcement: announcement,
                style: _announcementStyleForPhase(),
                onCompleted: _handleAnnouncementCompleted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlaying() => [
    if (widget.contentReady) widget.content,
    ..._buildTopBar(),
  ];

  /// 상단바는 진행·결과 단계에서 항상 그립니다. 손패가 비어 화면이 빈
  /// 순간에도 퇴장할 수 있어야 하기 때문입니다.
  List<Widget> _buildTopBar() {
    final topBar = widget.topBar;
    if (topBar == null || !widget.contentRevealed) return const [];
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: PhoneControlEntryAnimation(
            animation: _entryController,
            style: PhoneControlEntryStyle.header,
            begin: 0,
            end: 0.76,
            child: topBar,
          ),
        ),
      ),
    ];
  }

  GameAnnouncement? _announcementForPhase() {
    return switch (widget.phase) {
      GameScreenPhase.intro => GameAnnouncement.gameStart(
        duration: widget.gameStartAnnouncementDuration,
      ),
      GameScreenPhase.roundIntro => GameAnnouncement.round(
        widget.roundNumber,
        duration: widget.roundAnnouncementDuration,
      ),
      GameScreenPhase.closing => GameAnnouncement.persistent(
        id: 'closing',
        text: widget.closingMessage,
        blocksInteraction: true,
        showScrim: true,
      ),
      _ => null,
    };
  }

  GameAnnouncementStyle _announcementStyleForPhase() {
    if (widget.phase == GameScreenPhase.closing) {
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
