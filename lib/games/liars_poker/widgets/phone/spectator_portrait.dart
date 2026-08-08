import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class SpectatorPortrait extends StatelessWidget {
  final List<String> survivors;

  const SpectatorPortrait({super.key, required this.survivors});

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

          // 2. 상단 바 (기존 TopBar 에셋 활용)
          Positioned(
            top: 50.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Assets.games.liarsPoker.images.table.tableKingWhite.image(
                  height: 24.h,
                  filterQuality: FilterQuality.high,
                ),
                Row(
                  children: [
                    Assets.games.liarsPoker.images.icons.tip.image(
                      width: 40.w,
                      height: 40.h,
                    ),
                    SizedBox(width: 10.w),
                    Assets.games.liarsPoker.images.icons.settingPhone.image(
                      width: 32.w,
                      height: 32.h,
                    ),
                  ],
                ),
              ],
            ),
          ),

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

  // 생존자 목록 화이트 카드
  Widget _buildSurvivorCard() {
    return Container(
      width: 300.w,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.black87,
          width: 2,
        ), // 이중 테두리 효과를 위한 외곽선
      ),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade400, width: 1), // 내부 테두리
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
            ...survivors.map(
              (name) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(
                        Icons.person,
                        size: 20.r,
                        color: Colors.white,
                      ), // 더미 프로필
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      name,
                      style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
