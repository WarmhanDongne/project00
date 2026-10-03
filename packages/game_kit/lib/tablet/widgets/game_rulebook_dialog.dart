// [game_rulebook_dialog.dart] 는 태블릿 게임의 공통 룰북 다이얼로그를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:game_kit/tablet/widgets/game_modal_frame.dart';
import 'package:video_player/video_player.dart';
import 'package:game_kit/game_assets.dart';

// ============================================================

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
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo());
  }

  @override
  void didUpdateWidget(covariant _RuleVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      unawaited(_loadVideo());
    }
  }

  Future<void> _loadVideo() async {
    final generation = ++_loadGeneration;
    final url = widget.videoUrl?.trim() ?? '';
    final previousController = _controller;
    _controller = null;
    try {
      await previousController?.dispose();
    } catch (_) {
      // 이전 URL의 정리 실패가 새 영상 로드를 막지 않게 합니다.
    }
    if (!mounted || generation != _loadGeneration) return;

    if (url.isEmpty) {
      setState(() {});
      return;
    }

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {});
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _loadGeneration) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    unawaited(_controller?.dispose());
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
