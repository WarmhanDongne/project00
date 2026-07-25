import 'package:flutter/material.dart';

class ThreePlayerLayout extends StatefulWidget {
  const ThreePlayerLayout({super.key});

  @override
  State<ThreePlayerLayout> createState() => _ThreePlayerLayoutState();
}

class _ThreePlayerLayoutState extends State<ThreePlayerLayout> {
  bool isLandscape = true;

  final List<Offset> playerPositions = [
    const Offset(0.42, 0.10), // 태블릿 주인
    const Offset(0.12, 0.60), // 플레이어 2
    const Offset(0.70, 0.60), // 플레이어 3
  ];

  final List<String> playerNames = [
    '태블릿 주인',
    '이런 식의 닉네임',
    '주르르르륵',
  ];

  void movePlayer({
    required int index,
    required DragUpdateDetails details,
    required Size boardSize,
  }) {
    final currentPosition = playerPositions[index];

    final nextX =
        currentPosition.dx + details.delta.dx / boardSize.width;
    final nextY =
        currentPosition.dy + details.delta.dy / boardSize.height;

    setState(() {
      playerPositions[index] = Offset(
        nextX.clamp(0.0, 0.84),
        nextY.clamp(0.0, 0.80),
      );
    });
  }

  void completeSetting() {
    debugPrint('플레이어 위치: $playerPositions');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('자리 설정이 완료되었습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f3f3),
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:  900,
          height: 620,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xffeeeeee),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 22),

              const Text(
                '드래그를 사용하여 플레이어들의 실제 위치와 맞도록 조정해 주세요.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
                        for (int index = 0;
                            index < playerNames.length;
                            index++)
                          Positioned(
                            left: playerPositions[index].dx *
                                boardSize.width,
                            top: playerPositions[index].dy *
                                boardSize.height,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                movePlayer(
                                  index: index,
                                  details: details,
                                  boardSize: boardSize,
                                );
                              },
                              child: PlayerSlot(
                                nickname: playerNames[index],
                                isHost: index == 0,
                              ),
                            ),
                          ),

                        Positioned(
                          right: 24,
                          bottom: 14,
                          child: Row(
                            children: [
                              FilledButton(
                                onPressed: completeSetting,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xffd4d4d4),
                                  foregroundColor: Colors.black,
                                  shape: const RoundedRectangleBorder(),
                                ),
                                child: const Text('설정 완료'),
                              ),
                            ],
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
}

class PlayerSlot extends StatelessWidget {
  const PlayerSlot({
    super.key,
    required this.nickname,
    required this.isHost,
  });

  final String nickname;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Container(
        width: 132,
        height: 132,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xffd4d4d4),
        ),
        child: Text(
          nickname,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isHost ? 16 : 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}