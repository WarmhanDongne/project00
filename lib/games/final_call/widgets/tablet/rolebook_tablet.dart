import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:video_player/video_player.dart';

class RoleBook extends StatelessWidget {
  const RoleBook({super.key, required this.provider});

  final RoomProvider provider;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1300,
      height: 900,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 36,
            spreadRadius: 3,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BasicRole(provider: provider),
                  const Cards(),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Align(alignment: Alignment.topRight, child: Video()),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Button(
                      text: "닫기",
                      color: Colors.black,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BasicRole extends StatelessWidget {
  const BasicRole({super.key, required this.provider});

  final RoomProvider provider;
  final String markdown = '''
# 기본 규칙

각 플레이어는 생명 **3개**와 카드 **4장**으로 시작합니다.

- 자신의 턴에는 공개 카드 또는 덱의 카드 한 장을 가져옵니다.
- 가져온 카드는 손패 한 장과 교체하거나 그대로 버릴 수 있습니다.
- 자신의 패가 충분히 높다고 판단하면 **CALL**을 선언합니다.

## 점수 계산

- 같은 숫자 카드의 합
- 같은 색 카드의 합

두 값 중 더 높은 숫자가 최종 점수입니다.

## CALL 이후

CALL을 선언한 플레이어를 제외한 모든 플레이어는 마지막 교체를 한 번 진행합니다.
가장 낮은 점수의 플레이어는 생명 1개를 잃습니다.
CALL을 선언한 플레이어가 최하위라면 생명 2개를 잃습니다.

## 승리 조건

생명이 모두 소진된 플레이어는 탈락하며, 마지막 생존자가 승리합니다.
''';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.selectedGame!.name,
          style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 15),
        SingleChildScrollView(
          child: SizedBox(
            height: 350,
            child: Markdown(data: markdown, selectable: true),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}

class Cards extends StatelessWidget {
  const Cards({super.key});

  @override
  Widget build(BuildContext context) {
    final cardImages = <AssetGenImage>[
      Assets.games.finalCall.images.cards.cardRed10,
      Assets.games.finalCall.images.cards.cardBlue10,
      Assets.games.finalCall.images.cards.cardYellow10,
      Assets.games.finalCall.images.cards.cardGreen10,
    ];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "카드",
            style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: cardImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: cardImages[index].image(
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) {
                        return Container(
                          color: Colors.red.shade100,
                          alignment: Alignment.center,
                          child: const Text("Image Error"),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Video extends StatefulWidget {
  const Video({super.key});

  @override
  State<Video> createState() => _VideoState();
}

class _VideoState extends State<Video> {
  VideoPlayerController? _controller;

  /// 나중에 Firestore에서 받아올 값
  String? videoUrl;
  @override
  void initState() {
    super.initState();
    // videoUrl = rule.videoUrl;
    // if (videoUrl != null) {
    //   _initializeVideo();
    // }
  }

  // Future<void> _initializeVideo() async {
  //   _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl!));
  //   await _controller!.initialize();
  //   if (mounted) {
  //     setState(() {});
  //   }
  // }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// 아직 영상이 등록되지 않은 상태
    if (videoUrl == null) {
      return Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill_rounded, size: 90, color: Colors.grey),
          ],
        ),
      );
    }

    /// 영상 로딩 중
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    /// 실제 영상
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

class Button extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;

  const Button({
    super.key,
    required this.text,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(270, 70),
        backgroundColor: color,
        elevation: 12,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      ),
    );
  }
}
