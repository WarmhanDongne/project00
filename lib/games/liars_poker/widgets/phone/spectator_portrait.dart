import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart'; // 모델 임포트
import 'package:project00/gen/assets.gen.dart';

class SpectatorPortrait extends StatelessWidget {
  // 더미 텍스트 대신 실제 플레이어 모델 리스트를 받습니다.
  final List<PlayerLayoutPlayer> players;

  const SpectatorPortrait({super.key, required this.players});

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

          // ... (상단 바 생략 - 이전 답변과 동일) ...

          // 3. 중앙 관전중 텍스트 및 생존자 카드
          Positioned(
            top: 250.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "관전중......",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 30.h),
                _buildSurvivorCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 실제 데이터를 활용한 생존자 목록 화이트 카드
  Widget _buildSurvivorCard() {
    return Container(
      width: 300.w,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "생존",
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16.h),
            // 전달받은 players 리스트를 매핑하여 렌더링
            ...players.map((player) {
              final hasProfileImage = player.profileImageUrl.isNotEmpty;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: Colors.grey.shade300,
                      // 네트워크 이미지가 있으면 렌더링, 없으면 기본 아이콘
                      backgroundImage: hasProfileImage
                          ? NetworkImage(player.profileImageUrl)
                          : null,
                      child: hasProfileImage
                          ? null
                          : Icon(Icons.person, size: 20.r, color: Colors.white),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        player.nickname,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
