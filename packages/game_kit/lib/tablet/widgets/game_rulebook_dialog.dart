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
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';
import 'package:video_player/video_player.dart';
import 'package:game_kit/game_assets.dart';

// ============================================================

/// 규칙 문구와 게임별 카드 자산만 주입하는 공용 태블릿 룰북입니다.
///
/// 시안: 왼쪽은 규칙 영상과 카드, 오른쪽은 장을 넘기며 읽는 규칙입니다.
/// [markdown]의 `# 제목`마다 한 장으로 나눕니다.
class TabletGameRulebookDialog extends StatefulWidget {
  const TabletGameRulebookDialog({
    super.key,
    required this.title,
    required this.markdown,
    this.cardImages = const [],
    this.cards = const [],
    this.videoUrl,
  });

  final String title;
  final String markdown;
  final List<GameImage> cardImages;

  /// 카드를 그림 대신 위젯으로 그리는 게임이 씁니다. 64×90 칸에 맞춰 그립니다.
  final List<Widget> cards;
  final String? videoUrl;

  @override
  State<TabletGameRulebookDialog> createState() =>
      _TabletGameRulebookDialogState();
}

class _RulePage {
  const _RulePage(this.title, this.body);

  final String title;
  final String body;
}

/// 맨 윗단계 제목(`# `)마다 장을 나눕니다. 제목이 없으면 한 장입니다.
List<_RulePage> _splitPages(String markdown) {
  final pages = <_RulePage>[];
  String? title;
  final body = StringBuffer();
  void flush() {
    final text = body.toString().trim();
    if (title != null || text.isNotEmpty) {
      pages.add(_RulePage(title ?? '규칙', text));
    }
    body.clear();
  }

  for (final line in markdown.trim().split('\n')) {
    if (line.startsWith('# ')) {
      flush();
      title = line.substring(2).trim();
    } else {
      body.writeln(line);
    }
  }
  flush();
  return pages.isEmpty ? const [_RulePage('규칙', '')] : pages;
}

class _TabletGameRulebookDialogState extends State<TabletGameRulebookDialog> {
  late List<_RulePage> _pages = _splitPages(widget.markdown);
  int _page = 0;

  @override
  void didUpdateWidget(covariant TabletGameRulebookDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _pages = _splitPages(widget.markdown);
      _page = _page.clamp(0, _pages.length - 1);
    }
  }

  void _go(int page) =>
      setState(() => _page = page.clamp(0, _pages.length - 1));

  @override
  Widget build(BuildContext context) {
    final theme = MosiGameModalTheme.fromName(widget.title);
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;
    return MosiGameModalFrame(
      theme: theme,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      semanticLabel: '게임 규칙',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '게임 규칙',
                      style: MosiFonts.sans(
                        size: 34,
                        weight: FontWeight.w700,
                        color: MosiColors.navy,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.deep,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MosiFonts.sans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RuleVideo(videoUrl: widget.videoUrl, theme: theme),
                const SizedBox(height: 16),
                if (widget.cards.isNotEmpty) ...[
                  Text(
                    '카드',
                    style: MosiFonts.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.cards.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => SizedBox(
                        width: 64,
                        height: 96,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: widget.cards[index],
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.cardImages.isNotEmpty) ...[
                  Text(
                    '카드',
                    style: MosiFonts.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.cardImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => Container(
                        width: 64,
                        height: 90,
                        margin: const EdgeInsets.only(right: 3, bottom: 3),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: MosiColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MosiColors.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: MosiColors.ink,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: widget.cardImages[index].image(
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: MosiColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (index, item) in _pages.indexed)
                            Semantics(
                              button: true,
                              selected: index == _page,
                              label: item.title,
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: () => _go(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == _page
                                        ? theme.deep
                                        : MosiColors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: MosiColors.ink,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    item.title,
                                    style: MosiFonts.sans(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: index == _page
                                          ? MosiColors.white
                                          : MosiColors.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MosiSquareCloseButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(_page),
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
                      decoration: BoxDecoration(
                        color: MosiColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MosiColors.ink, width: 2),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(_page + 1).toString().padLeft(2, '0')} / '
                              '${_pages.length.toString().padLeft(2, '0')}',
                              style: MosiFonts.grotesk(
                                size: 13,
                                color: theme.deep,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              page.title,
                              style: MosiFonts.sans(
                                size: 28,
                                weight: FontWeight.w700,
                                color: MosiColors.navy,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            MarkdownBody(
                              data: page.body,
                              selectable: true,
                              styleSheet: _ruleStyleSheet(theme),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Opacity(
                      opacity: _page == 0 ? 0.4 : 1,
                      child: MosiButton(
                        label: '‹ 이전',
                        background: MosiColors.white,
                        shadowOffset: 0,
                        height: 56,
                        fontSize: 17,
                        radius: 12,
                        onPressed: _page == 0 ? null : () => _go(_page - 1),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? theme.deep
                                    : const Color(0x400E0A3D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: MosiButton(
                        label: isLast ? '다 읽었어요' : '다음 ›',
                        background: theme.accent,
                        foreground: theme.accentFg,
                        shadowColor: MosiColors.ink,
                        height: 56,
                        fontSize: 17,
                        radius: 12,
                        expand: true,
                        onPressed: isLast
                            ? () => Navigator.of(context).pop()
                            : () => _go(_page + 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

MarkdownStyleSheet _ruleStyleSheet(MosiGameModalTheme theme) {
  final body = MosiFonts.sans(size: 17, color: MosiColors.navy, height: 1.6);
  return MarkdownStyleSheet(
    p: body,
    strong: body.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: const Color(0x59F2C14E),
    ),
    h2: MosiFonts.sans(
      size: 20,
      weight: FontWeight.w700,
      color: MosiColors.navy,
    ),
    h2Padding: const EdgeInsets.only(top: 10),
    h3: MosiFonts.sans(
      size: 18,
      weight: FontWeight.w700,
      color: MosiColors.navy,
    ),
    listBullet: MosiFonts.grotesk(size: 15, color: theme.deep),
    blockSpacing: 12,
  );
}

/// 규칙 영상입니다. 누르면 재생·멈춤을 바꿉니다.
class _RuleVideo extends StatefulWidget {
  const _RuleVideo({this.videoUrl, required this.theme});

  final String? videoUrl;
  final MosiGameModalTheme theme;

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
      _controller = controller..addListener(_onTick);
      setState(() {});
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _loadGeneration) {
        setState(() {});
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      if (controller.value.position >= controller.value.duration) {
        unawaited(controller.seekTo(Duration.zero));
      }
      unawaited(controller.play());
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _controller?.removeListener(_onTick);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final playing = ready && controller.value.isPlaying;
    final hasUrl = (widget.videoUrl?.trim() ?? '').isNotEmpty;
    final duration = ready ? controller.value.duration : Duration.zero;
    final progress = ready && duration.inMilliseconds > 0
        ? controller.value.position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final label = !hasUrl
        ? '규칙 영상 준비 중'
        : !ready
        ? '영상을 불러오는 중'
        : playing
        ? '재생 중 · 누르면 멈춰요'
        : '규칙 영상 · 누르면 재생';
    return Semantics(
      button: ready,
      label: playing ? '규칙 영상 멈추기' : '규칙 영상 재생',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: ready ? _toggle : null,
        child: Container(
          width: 380,
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.theme.deep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MosiColors.ink, width: 3),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              if (!playing) const ColoredBox(color: Color(0x59000000)),
              if (!playing)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: hasUrl ? widget.theme.accent : MosiColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: MosiColors.ink, width: 3),
                    ),
                    child: Icon(
                      hasUrl ? Icons.play_arrow_rounded : Icons.videocam_off,
                      size: 34,
                      color: MosiColors.ink,
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xA6000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: MosiFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: MosiColors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(height: 5, color: widget.theme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
