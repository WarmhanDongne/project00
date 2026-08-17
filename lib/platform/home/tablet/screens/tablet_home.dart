import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

class _TabletHomeState extends State<TabletHome> {
  final RoomProvider roomProvider = RoomProvider();
  final GameProvider gameProvider = GameProvider();
  String searchWord = '';

  String? _presenceRoomCode;
  StreamSubscription<bool?>? _controllerRoomSubscription;

  @override
  void initState() {
    super.initState();
    //=======================초기 화면 방향 요청 금지==============================
    // 앱 첫 실행에서는 이 initState가 iOS scene 연결보다 먼저 호출될 수 있습니다.
    // 초기 태블릿 가로 고정은 main.dart가 lifecycle resumed 이후 한 번만 적용합니다.
    // 게임 종료 후 복원은 각 태블릿 게임 화면의 dispose가 담당합니다.
    //=======================진행 기기 접속 표시==============================
    // 방이 생기면 태블릿이 방을 열고 있다고 표시합니다. 태블릿이 사라지면
    // 서버가 방 전체를 삭제해 고아 방과 휴대폰의 무한 대기를 막습니다.
    roomProvider.addListener(_syncControllerPresence);
  }

  void _syncControllerPresence() {
    final code = roomProvider.roomCode;
    if (code == null) {
      _presenceRoomCode = null;
      unawaited(_controllerRoomSubscription?.cancel());
      _controllerRoomSubscription = null;
      return;
    }
    if (code == _presenceRoomCode) return;
    _presenceRoomCode = code;
    unawaited(roomProvider.markControllerConnected());
    unawaited(_controllerRoomSubscription?.cancel());
    _controllerRoomSubscription = roomProvider
        .watchControllerConnected(code)
        .listen((connected) {
          // 오프라인 중 RTDB 서버가 방을 삭제했다면, 재연결 후
          // 아이패드에 존재하지 않는 방 코드를 계속 표시하지 않습니다.
          if (connected == false && roomProvider.roomCode == code) {
            roomProvider.clearRoom();
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    roomProvider.removeListener(_syncControllerPresence);
    //=======================태블릿 정상 종료==============================
    // 로그아웃·화면 종료 시에는 onDisconnect 타임아웃을 기다리지 않고
    // 방을 즉시 삭제합니다. 앱 강제 종료는 서버 예약이 담당합니다.
    unawaited(roomProvider.deleteControllerRoom());
    unawaited(_controllerRoomSubscription?.cancel());
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
