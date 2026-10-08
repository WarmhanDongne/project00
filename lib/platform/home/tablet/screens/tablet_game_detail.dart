import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';

/// 로비 왼쪽에서만 교체되는 게임 소개입니다. 방 패널은 상위 로비가 유지합니다.
class TabletGameDetailContent extends StatefulWidget {
  const TabletGameDetailContent({
    super.key,
    required this.game,
    required this.roomProvider,
  });
  final GameInfo game;
  final RoomProvider roomProvider;
  @override
  State<TabletGameDetailContent> createState() =>
      _TabletGameDetailContentState();
}

enum _DetailTab { play, parts }

class _TabletGameDetailContentState extends State<TabletGameDetailContent> {
  _DetailTab _tab = _DetailTab.play;
  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(widget.game.id, fallbackName: widget.game.name);
    final theme = art.shelfTheme;
    final title = MosiGameArt.isKnown(widget.game.id)
        ? art.koreanName
        : widget.game.name;
    final range = gamePlayerRangeLabel(widget.game, widget.roomProvider);
    final description = widget.game.effectiveTabletDescription.isNotEmpty
        ? widget.game.effectiveTabletDescription
        : widget.game.description;

    return DefaultTextStyle(
      style: MosiFonts.sans(color: theme.fg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: MosiFonts.sans(
              size: 32,
              weight: FontWeight.w700,
              color: theme.fg,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                art.englishName,
                style: MosiFonts.grotesk(size: 13, color: art.accent),
              ),
              if (range.isNotEmpty)
                MosiPill(label: range, color: theme.fg, fontSize: 13),
              if (widget.game.playTime > 0)
                MosiPill(
                  label: '${widget.game.playTime}분',
                  color: theme.fg,
                  fontSize: 13,
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MosiFonts.sans(size: 15, color: theme.fg),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _DetailTabs(
              tab: _tab,
              theme: theme,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.deep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MosiColors.ink, width: 3),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: _buildPreview(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final scene = _tab == _DetailTab.play
        ? buildGamePlayPreview(widget.game.id)
        : buildGameParts(widget.game.id);
    if (scene != null) {
      return _tab == _DetailTab.play ? scene : GameDetailStage(child: scene);
    }
    // 미리보기가 등록되지 않은 게임은 서버의 구성품 사진을 보여 줍니다.
    final url = widget.game.componentImageUrl;
    if (url.isNotEmpty) {
      return Image.network(
        url,
        key: const Key('game-component-artwork'),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _PreviewUnavailable(),
      );
    }
    return const _PreviewUnavailable();
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.tab,
    required this.theme,
    required this.onChanged,
  });

  final _DetailTab tab;
  final MosiShelfTheme theme;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(_DetailTab value, String label, {bool divider = false}) {
      final selected = tab == value;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: () => onChanged(value),
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.fg : Colors.transparent,
              border: divider
                  ? Border(left: BorderSide(color: theme.fg, width: 2))
                  : null,
            ),
            child: Text(
              label,
              style: MosiFonts.sans(
                size: 15,
                weight: FontWeight.w700,
                color: selected ? theme.ground : theme.fg,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.fg, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(_DetailTab.play, '플레이 미리보기'),
          item(_DetailTab.parts, '구성품', divider: true),
        ],
      ),
    );
  }
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('unknown-game-preview-artwork'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.extension_outlined,
            color: Color(0x99FFFFFF),
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            '게임 미리보기를 준비 중입니다.',
            style: MosiFonts.sans(size: 13, color: const Color(0xCCFFFFFF)),
          ),
        ],
      ),
    );
  }
}
