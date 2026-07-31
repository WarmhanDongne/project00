import 'package:flutter/material.dart';

class FourPlayerLayout extends StatefulWidget {
  const FourPlayerLayout({super.key});

  @override
  State<FourPlayerLayout> createState() => _FourPlayerLayoutState();
}

class _FourPlayerLayoutState extends State<FourPlayerLayout> {
  static const double playerSlotSize = 160;

  // 이 거리 안으로 접근하면 즉시 자리 교환
  static const double swapTriggerDistance = 130;

  // 중앙 테이블을 감싸는 네 모서리
  final List<Offset> slotPositions = [
    const Offset(0.18, 0.05),
    const Offset(0.68, 0.05),
    const Offset(0.18, 0.69),
    const Offset(0.68, 0.69),
  ];

  final List<String> playerNames = ['태블릿 주인', '이런 식의 닉네임', '주르르르륵', '플레이어 4'];

  // playerSlotIndexes[플레이어 번호] = 현재 자리 번호
  List<int> playerSlotIndexes = [0, 1, 2, 3];

  // 드래그 중인 플레이어의 실제 위치
  final Map<int, Offset> draggingPositions = {};

  // 현재 드래그 중인 플레이어
  int? draggingPlayerIndex;

  // 같은 자리에서 계속 교환되는 것을 방지
  int? hoveredSlotIndex;

  void startDragging(int playerIndex) {
    final currentSlotIndex = playerSlotIndexes[playerIndex];

    setState(() {
      draggingPlayerIndex = playerIndex;
      hoveredSlotIndex = null;

      draggingPositions[playerIndex] = slotPositions[currentSlotIndex];
    });
  }

  void movePlayer({
    required int playerIndex,
    required DragUpdateDetails details,
    required Size boardSize,
  }) {
    final currentPosition =
        draggingPositions[playerIndex] ??
        slotPositions[playerSlotIndexes[playerIndex]];

    final maxX = 1 - (playerSlotSize / boardSize.width);
    final maxY = 1 - (playerSlotSize / boardSize.height);

    final nextPosition = Offset(
      (currentPosition.dx + details.delta.dx / boardSize.width).clamp(
        0.0,
        maxX,
      ),
      (currentPosition.dy + details.delta.dy / boardSize.height).clamp(
        0.0,
        maxY,
      ),
    );

    setState(() {
      draggingPositions[playerIndex] = nextPosition;
    });

    checkNearbySlot(
      playerIndex: playerIndex,
      draggingPosition: nextPosition,
      boardSize: boardSize,
    );
  }

  void checkNearbySlot({
    required int playerIndex,
    required Offset draggingPosition,
    required Size boardSize,
  }) {
    final draggedCenter = Offset(
      draggingPosition.dx * boardSize.width + playerSlotSize / 2,
      draggingPosition.dy * boardSize.height + playerSlotSize / 2,
    );

    final currentSlotIndex = playerSlotIndexes[playerIndex];

    int? nearbySlotIndex;
    double nearestDistance = double.infinity;

    for (int slotIndex = 0; slotIndex < slotPositions.length; slotIndex++) {
      // 현재 자신이 차지하고 있는 자리는 검사하지 않음
      if (slotIndex == currentSlotIndex) {
        continue;
      }

      final slotPosition = slotPositions[slotIndex];

      final slotCenter = Offset(
        slotPosition.dx * boardSize.width + playerSlotSize / 2,
        slotPosition.dy * boardSize.height + playerSlotSize / 2,
      );

      final distance = (draggedCenter - slotCenter).distance;

      if (distance <= swapTriggerDistance && distance < nearestDistance) {
        nearestDistance = distance;
        nearbySlotIndex = slotIndex;
      }
    }

    // 다른 자리 근처에 진입
    if (nearbySlotIndex != null) {
      // 이미 같은 자리에서 교환했다면 다시 실행하지 않음
      if (hoveredSlotIndex == nearbySlotIndex) {
        return;
      }

      swapPlayerSlotsWhileDragging(
        playerIndex: playerIndex,
        targetSlotIndex: nearbySlotIndex,
      );

      hoveredSlotIndex = nearbySlotIndex;
      return;
    }

    // 모든 자리의 감지 범위에서 벗어나야
    // 다시 같은 자리로 접근했을 때 교환 가능
    hoveredSlotIndex = null;
  }

  void swapPlayerSlotsWhileDragging({
    required int playerIndex,
    required int targetSlotIndex,
  }) {
    final currentSlotIndex = playerSlotIndexes[playerIndex];

    final targetPlayerIndex = playerSlotIndexes.indexOf(targetSlotIndex);

    if (currentSlotIndex == targetSlotIndex) {
      return;
    }

    setState(() {
      // 대상 자리에 있는 플레이어를
      // 드래그 플레이어의 기존 자리로 밀어냄
      if (targetPlayerIndex != -1 && targetPlayerIndex != playerIndex) {
        playerSlotIndexes[targetPlayerIndex] = currentSlotIndex;
      }

      // 드래그 플레이어가 대상 자리를 차지
      playerSlotIndexes[playerIndex] = targetSlotIndex;
    });
  }

  void finishDragging(int playerIndex) {
    setState(() {
      // 현재 차지한 고정 자리로 부드럽게 이동
      draggingPositions.remove(playerIndex);

      draggingPlayerIndex = null;
      hoveredSlotIndex = null;
    });
  }

  void cancelDragging(int playerIndex) {
    setState(() {
      draggingPositions.remove(playerIndex);

      draggingPlayerIndex = null;
      hoveredSlotIndex = null;
    });
  }

  void completeSetting() {
    final playerPositions = List<Offset>.generate(playerNames.length, (index) {
      final slotIndex = playerSlotIndexes[index];
      return slotPositions[slotIndex];
    });

    debugPrint('플레이어 자리 번호: $playerSlotIndexes');
    debugPrint('플레이어 위치: $playerPositions');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('자리 설정이 완료되었습니다.')));

    // 다음 화면으로 이동할 때
    //
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const NextPage(),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              const SizedBox(height: 22),
              const Text(
                '드래그를 사용하여 플레이어들의 실제 위치와 맞도록 조정해 주세요.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return Stack(
                      children: [
                        // 플레이어 표시
                        for (
                          int playerIndex = 0;
                          playerIndex < playerNames.length;
                          playerIndex++
                        )
                          _buildPlayer(
                            playerIndex: playerIndex,
                            boardSize: boardSize,
                          ),

                        Positioned(
                          right: 24,
                          bottom: 14,
                          child: FilledButton(
                            onPressed: completeSetting,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xffd4d4d4),
                              foregroundColor: Colors.black,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: const Text('설정 완료'),
                          ),
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
    );
  }

  Widget _buildPlayer({required int playerIndex, required Size boardSize}) {
    final isDragging = draggingPlayerIndex == playerIndex;

    final position = isDragging
        ? draggingPositions[playerIndex] ??
              slotPositions[playerSlotIndexes[playerIndex]]
        : slotPositions[playerSlotIndexes[playerIndex]];

    return AnimatedPositioned(
      key: ValueKey(playerIndex),

      // 드래그 중인 플레이어는 손을 즉시 따라감
      // 밀려나는 플레이어는 부드럽게 이동
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 350),

      curve: Curves.easeInOutCubic,

      left: position.dx * boardSize.width,
      top: position.dy * boardSize.height,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          startDragging(playerIndex);
        },
        onPanUpdate: (details) {
          movePlayer(
            playerIndex: playerIndex,
            details: details,
            boardSize: boardSize,
          );
        },
        onPanEnd: (_) {
          finishDragging(playerIndex);
        },
        onPanCancel: () {
          cancelDragging(playerIndex);
        },
        child: PlayerSlot(
          nickname: playerNames[playerIndex],
          isHost: playerIndex == 0,
        ),
      ),
    );
  }
}

class PlayerSlot extends StatelessWidget {
  const PlayerSlot({super.key, required this.nickname, required this.isHost});

  final String nickname;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        width: 160,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xffd4d4d4)),
        child: Text(
          nickname,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
