import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_button.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_list.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_search_bar.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';

class TabletHome extends StatefulWidget {
  const TabletHome({super.key});

  @override
  State<TabletHome> createState() => _TabletHomeState();
}

class _TabletHomeState extends State<TabletHome> {
  final RoomProvider roomProvider = RoomProvider();
  final GameProvider gameProvider=GameProvider();
  String searchWord = '';

  void searchChanged(String value) {
    setState(() {
      searchWord = value;
    });
  }

  @override
  void dispose() {
    roomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              children: [
                const AppButton(
                  text: '상점',
                  width: 160,
                  backgroundColor: Colors.blue,
                  onPressed: null,
                ),
                const SizedBox(width: 300),
                Expanded(child: GameSearchBar(onChanged: searchChanged)),
                const SizedBox(width: 300),
                AppButton(
                  text: 'Logout',
                  width: 160,
                  backgroundColor: Colors.blue,
                  onPressed: logout,
                ),
                const Profile(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: GameList(roomProvider: roomProvider, gameProvider: gameProvider),),
                  const SizedBox(width: 24),
                  TabletRoomPanel(provider: roomProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> logout() async {
  await FirebaseAuth.instance.signOut();
}
