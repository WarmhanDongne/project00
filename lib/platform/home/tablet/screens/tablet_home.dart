import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(AppOrientation.lockPlatformPortrait());
  }

  @override
  void dispose() {
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
      height: 74,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                '모시겜',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: GameSearchBar(onChanged: onSearchChanged),
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text(
                      '로그아웃',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
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
