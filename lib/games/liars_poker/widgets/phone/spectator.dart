import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/liars_poker/liars_poker_copy.dart';
import 'package:project00/games/liars_poker/widgets/phone/exit_modal.dart';
import 'package:project00/games/liars_poker/widgets/phone/settings_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/models/room_character.dart';

/// 화면 방향에 맞게 생존 플레이어를 표시하는 휴대폰 관전 화면입니다.
class PhoneSpectator extends StatelessWidget {
  const PhoneSpectator({
    super.key,
    required this.players,
    required this.table,
    required this.onExitRoom,
  });

  final List<PlayerLayoutPlayer> players;
  final String table;
  final Future<bool> Function() onExitRoom;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return isLandscape ? _buildLandscape(context) : _buildPortrait(context);
  }

  //=======================세로 관전 화면==============================
  Widget _buildPortrait(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //=======================배경 화면==============================
          // 진행 화면과 같은 세로 배경을 유지해야 관전 전환 중 배경 이미지가
          // 바뀌거나 새로 디코딩되며 번쩍이지 않습니다.
          Positioned.fill(child: _buildBackground(isLandscape: false)),

          //=======================공용 상단 바==============================
          Positioned(
            top: 18.h,
            left: 20.w,
            right: 20.w,
            child: SafeArea(bottom: false, child: _buildTopBar(context, false)),
          ),

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
  Widget _buildLandscape(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //=======================배경 화면==============================
          Positioned.fill(child: _buildBackground(isLandscape: true)),

          //=======================공용 상단 바==============================
          Positioned(
            top: 12,
            left: 30,
            right: 30,
            child: SafeArea(bottom: false, child: _buildTopBar(context, true)),
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
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32.r,
                      height: 32.r,
                      child: Image.asset(
                        roomCharacterAssetPath(player.characterId),
                        fit: BoxFit.contain,
                      ),
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
                return SizedBox(
                  width: 150,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Image.asset(
                          roomCharacterAssetPath(player.characterId),
                          fit: BoxFit.contain,
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

  Widget _buildBackground({required bool isLandscape}) {
    final background = isLandscape
        ? Assets.games.liarsPoker.images.background.background.game
        : Assets.games.liarsPoker.images.background.backgroundPhone.game;
    return background.image(
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }

  Widget _buildTopBar(BuildContext context, bool isLandscape) {
    return PhoneGameTopBar(
      isLandscape: isLandscape,
      leadingWidget: _tableAsset(table).image(
        height: isLandscape ? 30 : 34.h,
        filterQuality: FilterQuality.high,
      ),
      onSettingPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const PhoneSettingsDialog(),
      ),
      onTipPressedAt: (origin) => _showRules(context, origin),
      onOutPressedAt: (origin) =>
          unawaited(_showExitModal(context, origin: origin)),
    );
  }

  void _showRules(BuildContext context, Offset origin) {
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin,
      builder: (_) => const PhoneGameRuleDialog(
        title: "LIAR'S POKER",
        rules: LiarsPokerCopy.phoneRules,
        surfaceColor: Color(0xFF142119),
        foregroundColor: Colors.white,
        showSurface: false,
        dismissOnAnyTap: true,
      ),
    );
  }

  Future<void> _showExitModal(
    BuildContext context, {
    required Offset origin,
  }) async {
    final shouldExit = await PhoneExitModal.show(context, origin: origin);
    if (!context.mounted || shouldExit != true) return;
    final left = await onExitRoom();
    if (!context.mounted || left) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
  }

  GameImage _tableAsset(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite.game,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite.game,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite.game,
    };
  }
}
