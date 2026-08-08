import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/widgets/sideblock_tablet.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 규칙/설정 메뉴와 개발용 상태 선택기를 화면 위에 배치합니다.
class TabletGameOverlay extends StatelessWidget {
  const TabletGameOverlay({
    super.key,
    required this.provider,
    required this.status,
    required this.onDebugStatusChanged,
  });

  final RoomProvider provider;
  final GameStatus status;
  final ValueChanged<GameStatus?> onDebugStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 실제 배포 화면에서는 서버 상태를 수동으로 바꾸지 못하게 숨깁니다.
        if (kDebugMode)
          Positioned(
            top: 20,
            left: 20,
            child: _GameStatusSelector(
              status: status,
              onChanged: onDebugStatusChanged,
            ),
          ),
        Positioned(top: 20, right: 20, child: SideBlock(provider: provider)),
      ],
    );
  }
}

class _GameStatusSelector extends StatelessWidget {
  const _GameStatusSelector({required this.status, required this.onChanged});

  final GameStatus status;
  final ValueChanged<GameStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xee151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white38, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GameStatus>(
          value: status,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: const Color(0xff202020),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 28,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          items: GameStatus.values
              .map(
                (status) => DropdownMenuItem<GameStatus>(
                  value: status,
                  child: Text(
                    status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
