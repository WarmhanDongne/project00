import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';

class RoleBook extends StatelessWidget {
  const RoleBook({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1300,
      height: 900,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
                children: const [BasicRole(), Cards()],
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
  const BasicRole({super.key});

  final String markdown = '''
# 기본 규칙

자신의 차례가 되면 **1~3장**의 카드를 냅니다.

- 선언은 진실일 수도 있습니다.
- 선언은 거짓일 수도 있습니다.
- 다음 플레이어는 **LIAR!** 를 외칠 수 있습니다.

## 승리 조건

마지막까지 살아남는 플레이어가 승리합니다.
모든 카드를 먼저 버리거나 마지막까지 살아남으면 승리합니다.
''';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Liar's Poker",
          style: TextStyle(fontSize: 60, fontWeight: FontWeight.w700),
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
    final List<String> cardImages = [
      'assets/games/liars_poker/images/cards/white A.png',
      'assets/games/liars_poker/images/cards/white K.png',
      'assets/games/liars_poker/images/cards/white Q.png',
      'assets/games/liars_poker/images/cards/white Joker.png',
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
                    child: Image.asset(
                      cardImages[index],
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
