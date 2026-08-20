import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:project00/games/shared/widgets/tablet_game_modal_frame.dart';
import 'package:video_player/video_player.dart';
import 'package:project00/core/assets/game_image.dart';

/// 규칙 문구와 게임별 카드 자산만 주입하는 공용 태블릿 룰북입니다.
class TabletGameRulebookDialog extends StatelessWidget {
  const TabletGameRulebookDialog({
    super.key,
    required this.title,
    required this.markdown,
    required this.cardImages,
    this.videoUrl,
  });

  final String title;
  final String markdown;
  final List<GameImage> cardImages;
  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    return TabletGameModalFrame(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 350,
                    child: Markdown(data: markdown, selectable: true),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    '카드',
                    style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: cardImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: cardImages[index].image(
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.red.shade100,
                              alignment: Alignment.center,
                              child: const Text('Image Error'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: _RuleVideo(videoUrl: videoUrl),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TabletGameDialogButton(
                      text: '닫기',
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

class _RuleVideo extends StatefulWidget {
  const _RuleVideo({this.videoUrl});

  final String? videoUrl;

  @override
  State<_RuleVideo> createState() => _RuleVideoState();
}

class _RuleVideoState extends State<_RuleVideo> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _RuleVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) _loadVideo();
  }

  Future<void> _loadVideo() async {
    await _controller?.dispose();
    _controller = null;
    final url = widget.videoUrl?.trim() ?? '';
    if (url.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(
          Icons.play_circle_fill_rounded,
          size: 90,
          color: Colors.grey,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 500,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
