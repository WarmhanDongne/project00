import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';

/// 화면 방향에 맞게 생존 플레이어를 표시하는 휴대폰 관전 화면입니다.
class PhoneSpectator extends StatelessWidget {
  const PhoneSpectator({super.key, required this.players});

  final List<PlayerLayoutPlayer> players;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return isLandscape ? _buildLandscape() : _buildPortrait();
  }

  //=======================세로 관전 화면==============================
  Widget _buildPortrait() {
    return Scaffold(
      body: Stack(
        children: [
          //=======================배경 화면==============================
          Positioned.fill(child: _buildBackground()),

          //=======================관전 정보==============================
          Positioned(
            top: 250.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  '관전중......',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 30.h),
                _buildPortraitSurvivorCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //=======================가로 관전 화면==============================
  Widget _buildLandscape() {
    return Scaffold(
      body: Stack(
        children: [
          //=======================배경 화면==============================
          Positioned.fill(child: _buildBackground()),

          //=======================상단 바==============================
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
                Row(
                  children: [
                    Assets.games.liarsPoker.images.icons.iconRole.image(
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

          //=======================관전 정보==============================
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '관전중......',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLandscapeSurvivorCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //=======================세로 생존자 목록==============================
  Widget _buildPortraitSurvivorCard() {
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
              '생존',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16.h),
            ...players.map((player) {
              final hasProfileImage = player.profileImageUrl.isNotEmpty;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: Colors.grey.shade300,
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

  //=======================가로 생존자 목록==============================
  Widget _buildLandscapeSurvivorCard() {
    return Container(
      width: 550,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                '생존',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Container(height: 80, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: players.map((player) {
                final hasProfileImage = player.profileImageUrl.isNotEmpty;

                return SizedBox(
                  width: 150,
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

  Widget _buildBackground() {
    return Assets.games.liarsPoker.images.background.background.image(
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}
