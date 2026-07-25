import 'package:flutter/material.dart';
import 'package:project00/platform/hub/providers/room_provider.dart';
import 'package:project00/platform/hub/screens/home_tablet.dart';

// 기타 필요한 import 추가 (GameSearchBar, Profile, GameList, MemberTap 등)

class HomeMobile extends StatefulWidget {
  const HomeMobile({super.key});

  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
  final RoomProvider _roomProvider = RoomProvider();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 기존 home.dart와 동일하게 RoomProvider 초기화
    _roomProvider.initializePersonalRoom();
  }

  @override
  void dispose() {
    _roomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 상단 타이틀 영역에 검색창 배치
        title: const GameSearchBar(),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16.0), child: Profile()),
        ],
      ),
      // IndexedStack을 사용해 탭 전환 시 상태(스크롤 위치 등)를 유지
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 탭 0: 게임 목록
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GameList(roomProvider: _roomProvider, crossAxisCount: 2),
          ),

          // 탭 1: 방 관리 및 멤버 리스트
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: MemberTap(provider: _roomProvider),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '게임 목록'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: '대기방'),
        ],
      ),
    );
  }
}
