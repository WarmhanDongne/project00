import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/home/phone/widgets/session_return_prompt.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  late final Future<List<GameInfo>>
  _games; // PhoneGamePortraitCard에 들어갈 데이터 보관할 객체
  final GameService _gameService = GameService(); // 데이터 fetch할 객체
  final RoomProvider _restoredRoomProvider = RoomProvider();
  StreamSubscription<bool>? _connectionSubscription;
  bool _restoreInFlight = false;
  bool _waitingRoomOpen = false;

  /// 돌아갈 수 있는 세션입니다. none이 아니면 복귀 안내 화면을 띄웁니다.
  RestorableSession _restorable = RestorableSession.none;

  /// 이 앱 실행에서 사용자가 이미 복귀를 거절했습니다.
  ///
  /// 거절하면 저장 세션을 지우므로 보통은 다시 뜨지 않지만, 지우기 전에
  /// `.info/connected` 복구가 겹치면 안내가 한 번 더 뜰 수 있습니다.
  bool _declined = false;

  @override
  void initState() {
    super.initState();
    //================상태바 표시=================
    unawaited(AppSystemUi.showPlatformSystemBars());
    // 앱 첫 화면의 방향은 iOS scene이 resumed 된 뒤 main.dart에서 적용합니다.
    // 게임 종료 후 세로 복원은 휴대폰 게임 화면과 대기 화면이 담당합니다.
    _games = _gameService.fetchGames();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _connectionSubscription = _restoredRoomProvider
          .watchServerConnection()
          .listen(
            (connected) {
              if (connected) unawaited(_detectPreviousRoom());
            },
            // 연결 상태 스트림 오류가 unhandled exception으로 앱을 멈추지
            // 않게 합니다. 복원은 아래의 직접 호출로 한 번은 시도됩니다.
            onError: (_) {},
          );
      unawaited(_detectPreviousRoom());
    });
  }

  /// 돌아갈 세션이 있는지 **서버에 쓰지 않고** 확인만 합니다.
  ///
  /// 예전에는 여기서 곧바로 복원하고 대기 화면을 띄웠습니다. 게임을 그만두려고
  /// 앱을 껐어도 다시 켜면 그 방으로 끌려 들어갔습니다(P-01).
  Future<void> _detectPreviousRoom() async {
    if (_restoreInFlight || _waitingRoomOpen || _declined || !mounted) return;
    if (_restoredRoomProvider.isLeaving) return;
    if (_restoredRoomProvider.isInRoom) {
      await _openWaitingRoom();
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final restorable = await _restoredRoomProvider.detectRestorableSession();
    if (!mounted || _declined) return;
    setState(() => _restorable = restorable);
  }

  /// 사용자가 복귀를 골랐습니다. 이제서야 서버에 참가자를 되살립니다.
  Future<void> _acceptReturn() async {
    if (_restoreInFlight || _waitingRoomOpen || !mounted) return;
    // 라우트 확인을 복원 호출보다 먼저 합니다. restorePlayerRoom()은 서버에
    // 참가자를 다시 만들고 heartbeat를 시작하므로, 결과를 버릴 상황이면 애초에
    // 부르지 않아야 합니다.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _restoreInFlight = true);
    final restored = await _restoredRoomProvider.restorePlayerRoom();
    if (!mounted) return;
    setState(() {
      _restoreInFlight = false;
      if (restored) _restorable = RestorableSession.none;
    });
    if (!restored) return;
    await _openWaitingRoom();
  }

  Future<void> _declineReturn() async {
    setState(() {
      _declined = true;
      _restorable = RestorableSession.none;
    });
    // 서버에는 아직 아무것도 쓰지 않았으므로 저장 세션만 지웁니다. 방에 남아
    // 있는 참가자 노드는 서버 정리가 담당합니다(C-10).
    await _restoredRoomProvider.declineRestorableSession();
  }

  Future<void> _openWaitingRoom() async {
    if (_waitingRoomOpen ||
        !mounted ||
        !_restoredRoomProvider.isInRoom ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _waitingRoomOpen = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhoneRoomWaiting(provider: _restoredRoomProvider),
      ),
    );
    _waitingRoomOpen = false;
    if (mounted) setState(() => _restorable = RestorableSession.none);
  }

  Future<void> _openRoomJoin() async {
    if (_restoreInFlight || _waitingRoomOpen) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const PhoneRoomJoin()),
    );
    // 방금 직접 입장했다면 묻지 않고 그 방을 씁니다. 새로 들어간 방을 두고
    // '돌아가시겠어요?'를 묻는 것은 말이 되지 않습니다.
    _declined = false;
    if (mounted) unawaited(_detectPreviousRoom());
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _restoredRoomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restorable != RestorableSession.none) {
      return SessionReturnPrompt(
        session: _restorable,
        isBusy: _restoreInFlight,
        onReturn: () => unawaited(_acceptReturn()),
        onDecline: () => unawaited(_declineReturn()),
      );
    }
    final colors = context.platformColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const PhoneHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '보유 중인 게임',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '모바일에서는 방에 참여해 플레이합니다.',
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            PhoneOwnGameList(games: _games),
            _buildJoinBar(),
          ],
        ),
      ),
    );
  }

  //================하단 고정 그룹 참여 버튼=================
  Widget _buildJoinBar() {
    final colors = context.platformColors;
    final busy = _restoreInFlight || _waitingRoomOpen;
    return Container(
      width: double.infinity,
      color: colors.canvas,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: PlatformButton(
        label: busy ? '재접속 중' : '그룹 참여',
        height: 56,
        onPressed: busy ? null : () => unawaited(_openRoomJoin()),
      ),
    );
  }
}
