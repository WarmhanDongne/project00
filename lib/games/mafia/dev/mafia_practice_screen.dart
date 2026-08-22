import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/dev/mafia_practice_engine.dart';
import 'package:project00/games/mafia/dev/mafia_practice_remote_screen.dart';
import 'package:project00/games/mafia/dev/mafia_practice_server.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/screens/phone/phone_game_screen.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';
import 'package:project00/platform/home/room/models/room_character.dart';

//=======================마피아 연습장 (개발 전용)==============================
/// Firebase·다른 기기 없이 마피아 흐름 전체를 눈으로 보는 화면입니다.
///
/// 왼쪽은 실제 게임 화면(휴대폰/태블릿 전환), 오른쪽은 조종판입니다. 실제
/// 화면 위젯과 컨트롤러를 **그대로** 쓰므로 여기서 보이는 것이 실기기와 같고,
/// 핫 리로드로 바로 고쳐 볼 수 있습니다.
///
/// 진행은 [MafiaPracticeEngine]이 확정 타이밍(전원 확인 → 10초 → 안내 2.5초 →
/// 밤, 아침 8초, 발표 13초, 각 단계 마감)대로 알아서 굴립니다. 조종판으로
/// 마감을 앞당기거나 자동 진행을 끄고 수동으로 조작할 수도 있습니다.
class MafiaPracticeScreen extends ConsumerStatefulWidget {
  const MafiaPracticeScreen({super.key});

  @override
  ConsumerState<MafiaPracticeScreen> createState() =>
      _MafiaPracticeScreenState();
}

class _MafiaPracticeScreenState extends ConsumerState<MafiaPracticeScreen> {
  MafiaPracticeEngine? _engine;
  int _sessionSerial = 0;
  int _playerCount = 6;
  String? _myRoleId = 'mafia';
  bool _showsTablet = false;

  /// 봇 대신 실제 폰 시뮬레이터가 조작할 자리 수입니다(0 = 혼자 연습).
  int _humanPhoneCount = 0;

  /// 폰 시뮬레이터들이 붙는 연습 서버입니다. '사람 폰'이 1대 이상이면 켭니다.
  final MafiaPracticeServer _server = MafiaPracticeServer();

  MafiaSessionArgs? _phoneArgs;
  MafiaSessionArgs? _tabletArgs;

  /// 토론·투표 남은 시간을 1초마다 다시 계산해 그립니다.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _restart();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// 새 판을 시작합니다. 방 코드를 바꿔 컨트롤러도 새로 만듭니다.
  void _restart() {
    _engine?.dispose();
    _sessionSerial += 1;
    // 사람 자리: 혼자면 'me', 폰 시뮬레이터를 붙이면 접속 순서대로 p1·p2.
    final humanUids = _humanPhoneCount == 0
        ? const ['me']
        : [for (var i = 0; i < _humanPhoneCount; i += 1) 'p${i + 1}'];
    final engine = MafiaPracticeEngine(
      playerCount: _playerCount,
      humanUids: humanUids,
      preferredRoleId: _myRoleId,
    );
    if (_humanPhoneCount > 0) {
      // 서버는 켠 채 새 엔진으로 갈아 끼웁니다. 폰은 재접속할 필요 없습니다.
      unawaited(_server.start(engine));
    } else {
      unawaited(_server.stop());
    }
    setState(() {
      _engine = engine;
      _phoneArgs = MafiaSessionArgs(
        roomCode: 'DEV$_sessionSerial',
        // 왼쪽 미리보기는 첫 사람 자리를 봅니다. 폰 모드에서는 폰1과 같은
        // 화면이라, 폰 시뮬레이터와 나란히 비교할 때 씁니다.
        uid: humanUids.first,
        service: engine.practiceServiceFor(humanUids.first),
        watchPrivate: true,
      );
      _tabletArgs = MafiaSessionArgs(
        roomCode: 'DEV$_sessionSerial',
        uid: 'dev-tablet',
        service: engine.practiceServiceFor('dev-tablet'),
        // 태블릿과 같은 조건: 신분을 받지 않습니다.
        watchPrivate: false,
      );
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_server.stop());
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phoneArgs = _phoneArgs;
    final tabletArgs = _tabletArgs;
    final engine = _engine;
    if (phoneArgs == null || tabletArgs == null || engine == null) {
      return const SizedBox.shrink();
    }

    // 두 세션을 모두 구독해 둡니다. 보기 전환 때 화면이 초기화되지 않고,
    // autoDispose가 세션을 지우지 않습니다.
    ref.watch(mafiaSessionProvider(phoneArgs));
    ref.watch(mafiaSessionProvider(tabletArgs));

    return LayoutBuilder(
      builder: (context, constraints) {
        // 좁은 화면(휴대폰 세로)에서는 조종판을 오른쪽 서랍으로 뺍니다.
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: const Color(0xFF17191F),
          appBar: AppBar(
            title: const Text('마피아 연습장 (개발 전용)'),
            backgroundColor: const Color(0xFF10131A),
            foregroundColor: Colors.white,
          ),
          endDrawer: wide
              ? null
              : Drawer(child: SafeArea(child: _buildControls(engine))),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildDevice(engine, phoneArgs, tabletArgs)),
              if (wide) SizedBox(width: 300, child: _buildControls(engine)),
            ],
          ),
        );
      },
    );
  }

  //=======================왼쪽: 실제 게임 화면==============================
  Widget _buildDevice(
    MafiaPracticeEngine engine,
    MafiaSessionArgs phoneArgs,
    MafiaSessionArgs tabletArgs,
  ) {
    final args = _showsTablet ? tabletArgs : phoneArgs;
    final controller = ref.watch(mafiaSessionProvider(args).notifier);

    // 실기기 논리 크기 그대로 그린 뒤 화면에 맞게 축소합니다. 좌표 계산이
    // 실기기와 완전히 같아집니다.
    final deviceSize = _showsTablet
        ? const Size(1194, 834)
        : const Size(402, 874);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: deviceSize.width / deviceSize.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: deviceSize.width,
                  height: deviceSize.height,
                  child: _showsTablet
                      ? _buildTablet(engine, controller)
                      : MafiaPhoneGameScreen(controller: controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTablet(MafiaPracticeEngine engine, MafiaController controller) {
    final stage = resolveMafiaTabletStage(controller);
    // '밤이 됐습니다' 안내는 엔진이 지휘하므로 값만 구독해 그립니다.
    return ValueListenableBuilder<bool>(
      valueListenable: engine.nightNotice,
      builder: (context, showsNightNotice, _) => Stack(
        fit: StackFit.expand,
        children: [
          MafiaTabletBackground(isNight: controller.isNight),
          // 실기기(tablet_game.dart)와 같은 방식으로 1초마다 남은 시간을
          // 다시 셉니다. 서버 상태만 보고 그리면 연습장 타이머도 굳습니다.
          GameTurnCountdown(
            expiresAt: controller.turnDeadlineAt,
            builder: (context, remaining) => MafiaTabletStageView(
              stage: stage,
              controller: controller,
              playerLayout: _layoutOf(controller),
              remainingSeconds: remaining?.inSeconds,
              showsNightNotice: showsNightNotice,
              onRestart: _restart,
              onHome: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  /// 게임 상태의 플레이어로 좌석 배치를 만듭니다. 캐릭터는 순서대로 돌려 씁니다.
  PlayerLayoutModel _layoutOf(MafiaController controller) {
    final players = controller.players.values.toList()
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    return PlayerLayoutModel(
      players: [
        for (var i = 0; i < players.length; i += 1)
          PlayerLayoutPlayer(
            uid: players[i].uid,
            nickname: players[i].nickname,
            characterId: roomCharacters[i % roomCharacters.length].id,
            seatIndex: players[i].seatIndex,
          ),
      ],
    );
  }

  //=======================오른쪽: 조종판==============================
  Widget _buildControls(MafiaPracticeEngine engine) {
    // ListTile류는 배경을 Material에 그리므로 Container 색 대신 Material을 씁니다.
    return Material(
      color: const Color(0xFF10131A),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionLabel('여러 기기 (시뮬레이터)'),
          // 폰 시뮬레이터에서는 이 버튼으로 호스트(태블릿)에 접속합니다.
          _controlButton(
            '이 기기를 폰으로 접속',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MafiaPracticeRemoteScreen(),
              ),
            ),
          ),
          Row(
            children: [
              const Text('사람 폰', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _humanPhoneCount,
                dropdownColor: const Color(0xFF222630),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('없음 (혼자)')),
                  DropdownMenuItem(value: 1, child: Text('1대')),
                  DropdownMenuItem(value: 2, child: Text('2대')),
                ],
                onChanged: (value) =>
                    setState(() => _humanPhoneCount = value ?? 0),
              ),
            ],
          ),
          ValueListenableBuilder<List<String>>(
            valueListenable: _server.connectedNames,
            builder: (context, names, _) {
              if (!_server.isRunning) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '서버 ws://127.0.0.1:${_server.port} · 접속: '
                  '${names.isEmpty ? '없음' : names.join(', ')}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _sectionLabel('보기'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('휴대폰')),
              ButtonSegment(value: true, label: Text('태블릿')),
            ],
            selected: {_showsTablet},
            onSelectionChanged: (selection) =>
                setState(() => _showsTablet = selection.first),
          ),
          const SizedBox(height: 16),
          _sectionLabel('새 판'),
          Row(
            children: [
              const Text('인원', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _playerCount,
                dropdownColor: const Color(0xFF222630),
                style: const TextStyle(color: Colors.white),
                items: [
                  for (final count in [4, 5, 6, 7, 8, 9, 10, 11, 12])
                    DropdownMenuItem(value: count, child: Text('$count명')),
                ],
                onChanged: (value) => setState(() => _playerCount = value ?? 6),
              ),
            ],
          ),
          Row(
            children: [
              const Text('내 역할', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  value: _myRoleId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF222630),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('무작위')),
                    // 전향으로만 생기는 역할(광신도)은 빠집니다. 교주 없이
                    // 시작하면 교단 승리 조건이 성립하지 않습니다.
                    for (final role in MafiaRoles.distributable)
                      DropdownMenuItem(
                        value: role.id,
                        child: Text(role.displayName),
                      ),
                  ],
                  onChanged: (value) => setState(() => _myRoleId = value),
                ),
              ),
            ],
          ),
          FilledButton(onPressed: _restart, child: const Text('새 판 시작')),
          const SizedBox(height: 16),
          _sectionLabel('봇'),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 진행', style: TextStyle(color: Colors.white)),
            value: engine.autoPlay,
            onChanged: (value) => setState(() => engine.autoPlay = value),
          ),
          _controlButton('봇 지금 행동', () => engine.stepBots()),
          _controlButton('봇 토론 조기 종료', engine.botsSkipDiscussion),
          const SizedBox(height: 16),
          _sectionLabel('단계 넘기기'),
          _controlButton('밤 시작 (배분 완료)', engine.completeRoleReveal),
          _controlButton('밤 마감', engine.timeoutNightNow),
          _controlButton('아침 완료 → 낮', engine.completeMorning),
          _controlButton('토론 마감 → 투표', engine.timeoutDay),
          _controlButton('투표 마감 → 개표', engine.timeoutVoteNow),
          _controlButton('발표 완료 → 다음 밤', engine.completeVoteResult),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _controlButton(String label, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white30),
      ),
      child: Text(label),
    ),
  );
}
