import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/widgets/player_layouts/player_slot_positions.dart';

typedef PlayerLayoutCompleted = void Function(PlayerLayoutModel playerLayout);

/// 2~6명의 플레이어 자리를 하나의 화면에서 배치하는 편집기입니다.
class PlayerLayoutEditor extends StatefulWidget {
  PlayerLayoutEditor({
    super.key,
    required this.initialLayout,
    required this.onComplete,
  }) : assert(
         initialLayout.playerCount >= 2 && initialLayout.playerCount <= 6,
         '지원하는 플레이어 수는 2~6명입니다.',
       );

  final PlayerLayoutModel initialLayout;
  final PlayerLayoutCompleted onComplete;

  @override
  State<PlayerLayoutEditor> createState() => _PlayerLayoutEditorState();
}

class _PlayerLayoutEditorState extends State<PlayerLayoutEditor> {
  static const double _playerSlotSize = 160;
  static const double _swapTriggerDistance = 130;

  late List<int> _playerSlotIndexes;
  List<Offset> _slotPositions = const [];
  final Map<int, Offset> _draggingPositions = {};

  int? _draggingPlayerIndex;
  int? _hoveredSlotIndex;

  int get _playerCount => widget.initialLayout.playerCount;

  @override
  void initState() {
    super.initState();
    _playerSlotIndexes = List<int>.from(widget.initialLayout.seatIndexes);
  }

  void _startDragging(int playerIndex) {
    final currentSlotIndex = _playerSlotIndexes[playerIndex];

    setState(() {
      _draggingPlayerIndex = playerIndex;
      _hoveredSlotIndex = null;
      _draggingPositions[playerIndex] = _slotPositions[currentSlotIndex];
    });
  }

  void _movePlayer({
    required int playerIndex,
    required DragUpdateDetails details,
    required Size boardSize,
  }) {
    final currentPosition =
        _draggingPositions[playerIndex] ??
        _slotPositions[_playerSlotIndexes[playerIndex]];

    final maxX = math.max(0.0, 1 - (_playerSlotSize / boardSize.width));
    final maxY = math.max(0.0, 1 - (_playerSlotSize / boardSize.height));
    final nextPosition = Offset(
      (currentPosition.dx + details.delta.dx / boardSize.width).clamp(0, maxX),
      (currentPosition.dy + details.delta.dy / boardSize.height).clamp(0, maxY),
    );

    setState(() {
      _draggingPositions[playerIndex] = nextPosition;
    });

    _checkNearbySlot(
      playerIndex: playerIndex,
      draggingPosition: nextPosition,
      boardSize: boardSize,
    );
  }

  void _checkNearbySlot({
    required int playerIndex,
    required Offset draggingPosition,
    required Size boardSize,
  }) {
    final draggedCenter = Offset(
      draggingPosition.dx * boardSize.width + _playerSlotSize / 2,
      draggingPosition.dy * boardSize.height + _playerSlotSize / 2,
    );
    final currentSlotIndex = _playerSlotIndexes[playerIndex];

    int? nearbySlotIndex;
    double nearestDistance = double.infinity;

    for (var slotIndex = 0; slotIndex < _slotPositions.length; slotIndex++) {
      if (slotIndex == currentSlotIndex) continue;

      final slotPosition = _slotPositions[slotIndex];
      final slotCenter = Offset(
        slotPosition.dx * boardSize.width + _playerSlotSize / 2,
        slotPosition.dy * boardSize.height + _playerSlotSize / 2,
      );
      final distance = (draggedCenter - slotCenter).distance;

      if (distance <= _swapTriggerDistance && distance < nearestDistance) {
        nearestDistance = distance;
        nearbySlotIndex = slotIndex;
      }
    }

    if (nearbySlotIndex == null) {
      _hoveredSlotIndex = null;
      return;
    }
    if (_hoveredSlotIndex == nearbySlotIndex) return;

    _swapPlayerSlots(
      playerIndex: playerIndex,
      targetSlotIndex: nearbySlotIndex,
    );
    _hoveredSlotIndex = nearbySlotIndex;
  }

  void _swapPlayerSlots({
    required int playerIndex,
    required int targetSlotIndex,
  }) {
    final currentSlotIndex = _playerSlotIndexes[playerIndex];
    if (currentSlotIndex == targetSlotIndex) return;

    final targetPlayerIndex = _playerSlotIndexes.indexOf(targetSlotIndex);
    setState(() {
      if (targetPlayerIndex != -1 && targetPlayerIndex != playerIndex) {
        _playerSlotIndexes[targetPlayerIndex] = currentSlotIndex;
      }
      _playerSlotIndexes[playerIndex] = targetSlotIndex;
    });
  }

  void _finishDragging(int playerIndex) {
    setState(() {
      _draggingPositions.remove(playerIndex);
      _draggingPlayerIndex = null;
      _hoveredSlotIndex = null;
    });
  }

  void _completeSetting() {
    final completedLayout = widget.initialLayout.updateSeats(
      _playerSlotIndexes,
    );

    debugPrint('플레이어 자리 번호: ${completedLayout.seatIndexes}');
    widget.onComplete(completedLayout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                  _slotPositions = normalizedPlayerSlotTopLeftPositions(
                    playerCount: _playerCount,
                    boardSize: boardSize,
                    slotSize: _playerSlotSize,
                  );

                  return Stack(
                    children: [
                      for (
                        var playerIndex = 0;
                        playerIndex < _playerCount;
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
                          onPressed: _completeSetting,
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
    );
  }

  Widget _buildPlayer({required int playerIndex, required Size boardSize}) {
    final player = widget.initialLayout.players[playerIndex];
    final isDragging = _draggingPlayerIndex == playerIndex;
    final position = isDragging
        ? _draggingPositions[playerIndex] ??
              _slotPositions[_playerSlotIndexes[playerIndex]]
        : _slotPositions[_playerSlotIndexes[playerIndex]];

    return AnimatedPositioned(
      key: ValueKey(player.uid),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: position.dx * boardSize.width,
      top: position.dy * boardSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _startDragging(playerIndex),
        onPanUpdate: (details) => _movePlayer(
          playerIndex: playerIndex,
          details: details,
          boardSize: boardSize,
        ),
        onPanEnd: (_) => _finishDragging(playerIndex),
        onPanCancel: () => _finishDragging(playerIndex),
        child: _PlayerSlot(player: player),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({required this.player});

  final PlayerLayoutPlayer player;

  @override
  Widget build(BuildContext context) {
    final hasProfileImage = player.profileImageUrl.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        width: _PlayerLayoutEditorState._playerSlotSize,
        height: _PlayerLayoutEditorState._playerSlotSize,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Color(0xffd4d4d4)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: hasProfileImage
                  ? NetworkImage(player.profileImageUrl)
                  : null,
              child: hasProfileImage ? null : const Icon(Icons.person),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (player.isHost) ...[
                  const Icon(Icons.star, size: 18, color: Colors.orange),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    player.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
