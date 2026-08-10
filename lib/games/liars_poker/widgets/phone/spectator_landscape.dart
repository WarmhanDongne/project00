import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';

class SpectatorLandscape extends StatelessWidget {
  final List<PlayerLayoutPlayer> players;

  const SpectatorLandscape({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경
          Positioned.fill(
            child: Assets.games.liarsPoker.images.background.background.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 2. 상단 바 및 타이머
          Positioned(
            top: 20,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Assets.games.liarsPoker.images.table.tableKingWhite.image(
                  height: 30,
                  filterQuality: FilterQuality.high,
                ),
                // 타이머 컨테이너
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 16,
                //     vertical: 8,
                //   ),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   child: const Text(
                //     "00:30",
                //     style: TextStyle(
                //       fontSize: 20,
                //       fontWeight: FontWeight.bold,
                //       color: Colors.black,
                //     ),
                //   ),
                // ),
                Row(
                  children: [
                    Assets.games.liarsPoker.images.icons.iconTip.image(
                      width: 45,
                      height: 45,
                    ),
                    const SizedBox(width: 15),
                    Assets.games.liarsPoker.images.icons.iconOut.image(
                      width: 32,
                      height: 32,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. 중앙 관전중 텍스트 및 하단 생존자 카드
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "관전중......",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSurvivorCardLandscape(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 가로형 생존자 목록 화이트 카드
  Widget _buildSurvivorCardLandscape() {
    return Container(
      width: 550, // 가로 모드에 맞게 넓게 설정
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 좌측 생존 타이틀
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "생존",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // 중앙 구분선
          Container(height: 80, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 20),

          // 우측 생존자 리스트 (Wrap을 사용하여 2열로 자동 배치)
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: players.map((player) {
                final hasProfileImage = player.profileImageUrl.isNotEmpty;

                return SizedBox(
                  width: 150, // 각 항목의 고정 너비
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: hasProfileImage
                            ? NetworkImage(player.profileImageUrl)
                            : null,
                        child: hasProfileImage
                            ? null
                            : const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.nickname,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
