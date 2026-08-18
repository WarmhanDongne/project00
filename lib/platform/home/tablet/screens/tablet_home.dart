import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/games/shared/player_layouts/player_layout_factory.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_list.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_search_bar.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================태블릿 플랫폼 홈==============================
class TabletHome extends StatefulWidget {
  const TabletHome({super.key});

  @override
  State<TabletHome> createState() => _TabletHomeState();
}

class _TabletHomeState extends State<TabletHome> with WidgetsBindingObserver {
  final RoomProvider roomProvider = RoomProvider();
  final GameProvider gameProvider = GameProvider();
  String searchWord = '';
  StreamSubscription<String?>? _restoredGameStatusSubscription;
  String? _restoredStatusRoomCode;
  bool _isOpeningRestoredGame = false;

  @override
  void initState() {
    super.initState();
    //=======================초기 화면 방향 요청 금지==============================
    // 앱 첫 실행에서는 이 initState가 iOS scene 연결보다 먼저 호출될 수 있습니다.
    // 초기 태블릿 가로 고정은 main.dart가 lifecycle resumed 이후 한 번만 적용합니다.
    // 게임 종료 후 복원은 각 태블릿 게임 화면의 dispose가 담당합니다.
    //=======================controller 방 복구==============================
    // dispose나 lifecycle은 방 삭제 신호가 아닙니다. 저장된 session으로 기존
    // 방을 복구하고, background에서는 heartbeat만 멈춥니다.
    WidgetsBinding.instance.addObserver(this);
    roomProvider.addListener(_syncRestoredGame);
    unawaited(roomProvider.restoreControllerRoom());
  }

  void _syncRestoredGame() {
    final code = roomProvider.roomCode;
    if (code == null) {
      _restoredStatusRoomCode = null;
      unawaited(_restoredGameStatusSubscription?.cancel());
      _restoredGameStatusSubscription = null;
      return;
    }
    if (_restoredStatusRoomCode == code) return;
    _restoredStatusRoomCode = code;
    unawaited(_restoredGameStatusSubscription?.cancel());
    _restoredGameStatusSubscription = roomProvider.watchGameStatus(code).listen(
      (status) {
        if (status == 'playing') _openRestoredGameIfReady(code);
      },
      onError: (_) {},
    );
  }

  void _openRestoredGameIfReady(String roomCode) {
    if (_isOpeningRestoredGame ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final gameId = roomProvider.selectedGameId;
    final game = gameId == null ? null : GameRegistry.find(gameId);
    if (game == null || roomProvider.players.isEmpty) {
      Future<void>.delayed(
        const Duration(milliseconds: 150),
        () => _openRestoredGameIfReady(roomCode),
      );
      return;
    }

    final players = [...roomProvider.players]
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final savedSeats = players.map((player) => player.seatIndex).toSet();
    final hasValidSavedSeats =
        savedSeats.length == players.length &&
        savedSeats.every((seat) => seat >= 0 && seat < players.length);
    final layout = hasValidSavedSeats
        ? PlayerLayoutModel(
            players: List.unmodifiable(
              players.map(
                (player) => PlayerLayoutPlayer(
                  uid: player.uid,
                  nickname: player.nickname,
                  profileImageUrl: player.profileImageUrl,
                  seatIndex: player.seatIndex,
                ),
              ),
            ),
          )
        : PlayerLayoutFactory.create(players);

    _isOpeningRestoredGame = true;
    unawaited(AppOrientation.lockTabletGameLandscape());
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => game.buildTabletScreen(
              playerLayout: layout,
              provider: roomProvider,
              roomCode: roomCode,
            ),
          ),
        )
        .whenComplete(() => _isOpeningRestoredGame = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(roomProvider.resumeControllerPresence());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(roomProvider.pauseControllerPresence());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    roomProvider.removeListener(_syncRestoredGame);
    unawaited(_restoredGameStatusSubscription?.cancel());
    // 화면 dispose는 명시적 방 종료가 아닙니다. heartbeat만 정리하고 방과
    // controller session은 재접속 유예시간 동안 서버에 유지합니다.
    unawaited(roomProvider.pauseControllerPresence());
    roomProvider.dispose();
    gameProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _HomeHeader(
                  onSearchChanged: (value) {
                    setState(() => searchWord = value);
                  },
                ),
                Divider(height: 1, color: colors.border),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final panelWidth = (constraints.maxWidth * 0.25).clamp(
                        220.0,
                        310.0,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GameList(
                              roomProvider: roomProvider,
                              gameProvider: gameProvider,
                              searchQuery: searchWord,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: colors.border,
                          ),
                          SizedBox(
                            width: panelWidth,
                            child: TabletRoomPanel(provider: roomProvider),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(
              width: 170,
              child: Text(
                '모시겜',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: GameSearchBar(onChanged: onSearchChanged),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text(
                      '로그아웃',
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Profile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
