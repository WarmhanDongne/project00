import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
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
              if (connected) unawaited(_restorePreviousRoom());
            },
            // 연결 상태 스트림 오류가 unhandled exception으로 앱을 멈추지
            // 않게 합니다. 복원은 아래의 직접 호출로 한 번은 시도됩니다.
            onError: (_) {},
          );
      unawaited(_restorePreviousRoom());
    });
  }

  Future<void> _restorePreviousRoom() async {
    if (_restoreInFlight || _waitingRoomOpen || !mounted) return;
    setState(() => _restoreInFlight = true);
    final restored =
        _restoredRoomProvider.isInRoom ||
        await _restoredRoomProvider.restorePlayerRoom();
    if (!mounted) return;
    setState(() => _restoreInFlight = false);
    if (!restored || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    _waitingRoomOpen = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhoneRoomWaiting(provider: _restoredRoomProvider),
      ),
    );
    _waitingRoomOpen = false;
  }

  Future<void> _openRoomJoin() async {
    if (_restoreInFlight || _waitingRoomOpen) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const PhoneRoomJoin()),
    );
    if (mounted) unawaited(_restorePreviousRoom());
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _restoredRoomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
