import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/store/models/game_bundle.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';

/// 상점 상품에서 열리는 플레이 미리보기·구성품 화면입니다.
class TabletStoreGameDetail extends StatefulWidget {
  const TabletStoreGameDetail({super.key, required this.game});

  final GameInfo game;

  @override
  State<TabletStoreGameDetail> createState() => _TabletStoreGameDetailState();
}

enum _StoreDetailTab { preview, components }

class _TabletStoreGameDetailState extends State<TabletStoreGameDetail> {
  _StoreDetailTab _tab = _StoreDetailTab.preview;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final locale = Localizations.localeOf(context);
    final art = MosiGameArt.of(game.id, fallbackName: game.name);
    final theme = art.shelfTheme;
    final scene = _tab == _StoreDetailTab.preview
        ? buildGamePlayPreview(game.id)
        : buildGameParts(game.id);

    return Scaffold(
      backgroundColor: MosiColors.cream,
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1194,
              height: 834,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(38, 24, 38, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        MosiButton(
                          label: GameLocale.select(
                            ko: '상점으로',
                            en: 'BACK TO STORE',
                            zhHans: '返回商店',
                            zhHant: '返回商店',
                          ),
                          background: MosiColors.white,
                          height: 48,
                          radius: 10,
                          shadowOffset: 4,
                          fontSize: 15,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Text(
                          GameLocale.select(
                            ko: '게임 상세',
                            en: 'GAME DETAILS',
                            zhHans: '游戏详情',
                            zhHant: '遊戲詳情',
                          ),
                          style: MosiFonts.grotesk(
                            size: 19,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                            letterSpacing: 3,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 150),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.localizedName(locale),
                                style: MosiFonts.sans(
                                  size: 34,
                                  weight: FontWeight.w900,
                                  color: theme.fg,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                game.effectiveTabletDescriptionFor(locale),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: MosiFonts.sans(
                                  size: 16,
                                  color: theme.fg.withValues(alpha: .78),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        _StoreDetailTabs(
                          selected: _tab,
                          color: theme.fg,
                          onChanged: (value) => setState(() => _tab = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: theme.deep,
                          border: Border.all(color: MosiColors.ink, width: 3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: scene == null
                            ? Center(
                                child: Text(
                                  GameLocale.select(
                                    ko: '미리보기를 준비하고 있어요.',
                                    en: 'Preview coming soon.',
                                    zhHans: '预览即将推出。',
                                    zhHant: '預覽即將推出。',
                                  ),
                                  style: MosiFonts.sans(
                                    size: 19,
                                    color: MosiColors.white,
                                  ),
                                ),
                              )
                            : MediaQuery.withNoTextScaling(
                                child: _tab == _StoreDetailTab.preview
                                    ? scene
                                    : GameDetailStage(child: scene),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreDetailTabs extends StatelessWidget {
  const _StoreDetailTabs({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  final _StoreDetailTab selected;
  final Color color;
  final ValueChanged<_StoreDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final preview = GameLocale.select(
      ko: '플레이 미리보기',
      en: 'PREVIEW',
      zhHans: '玩法预览',
      zhHant: '玩法預覽',
    );
    final components = GameLocale.select(
      ko: '구성품',
      en: 'COMPONENTS',
      zhHans: '游戏配件',
      zhHant: '遊戲配件',
    );
    return Container(
      decoration: BoxDecoration(
        color: MosiColors.white,
        border: Border.all(color: MosiColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoreDetailTabButton(
            label: preview,
            selected: selected == _StoreDetailTab.preview,
            color: color,
            onTap: () => onChanged(_StoreDetailTab.preview),
          ),
          _StoreDetailTabButton(
            label: components,
            selected: selected == _StoreDetailTab.components,
            color: color,
            onTap: () => onChanged(_StoreDetailTab.components),
          ),
        ],
      ),
    );
  }
}

class _StoreDetailTabButton extends StatelessWidget {
  const _StoreDetailTabButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 148, minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: MosiFonts.sans(
            size: 15,
            weight: FontWeight.w800,
            color: selected ? MosiColors.white : color,
          ),
        ),
      ),
    ),
  );
}

/// 번들 구성 게임과 각 게임의 개별 소유권을 보여주는 상점 상세입니다.
class TabletStoreBundleDetail extends StatelessWidget {
  const TabletStoreBundleDetail({
    super.key,
    required this.bundle,
    required this.games,
  });

  final GameBundle bundle;
  final List<GameInfo> games;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final ownedCount = games.where((game) => game.isOwned).length;
    return Scaffold(
      backgroundColor: MosiColors.cream,
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1194,
              height: 834,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 28, 48, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        MosiButton(
                          label: GameLocale.select(
                            ko: '상점으로',
                            en: 'BACK TO STORE',
                            zhHans: '返回商店',
                            zhHant: '返回商店',
                          ),
                          background: MosiColors.white,
                          height: 48,
                          radius: 10,
                          shadowOffset: 4,
                          fontSize: 15,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Text(
                          GameLocale.select(
                            ko: '게임 묶음 구성',
                            en: 'BUNDLE CONTENTS',
                            zhHans: '组合内容',
                            zhHant: '組合內容',
                          ),
                          style: MosiFonts.grotesk(
                            size: 19,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                            letterSpacing: 3,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 150),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      bundle.localizedName(locale),
                      style: MosiFonts.sans(
                        size: 36,
                        weight: FontWeight.w900,
                        color: MosiColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bundle.localizedDescription(locale),
                      style: MosiFonts.sans(
                        size: 17,
                        color: MosiColors.navy,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      GameLocale.select(
                        ko: '현재 $ownedCount / ${games.length}종 보유 · 묶음 구매 후에도 게임별 소유권으로 각각 관리됩니다.',
                        en: '$ownedCount of ${games.length} owned · Each included game remains a separate entitlement.',
                        zhHans:
                            '当前已拥有 $ownedCount / ${games.length} 款 · 组合购买后仍按单款游戏分别管理所有权。',
                        zhHant:
                            '目前已擁有 $ownedCount / ${games.length} 款 · 組合購買後仍按單款遊戲分別管理所有權。',
                      ),
                      style: MosiFonts.sans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: MosiColors.violet,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 1.55,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final game in games)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: MosiColors.white,
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: MosiColors.navy,
                                    offset: Offset(5, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 92,
                                    child: MosiGameCover(
                                      gameId: game.id,
                                      width: 92,
                                      shadow: 0,
                                      fallbackName: game.name,
                                      fallbackImageUrl: game.imageUrl,
                                      displayName: game.localizedName(locale),
                                      englishName: game.englishName,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          game.localizedName(locale),
                                          style: MosiFonts.sans(
                                            size: 21,
                                            weight: FontWeight.w900,
                                            color: MosiColors.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          game.isOwned
                                              ? GameLocale.select(
                                                  ko: '개별 보유 중',
                                                  en: 'OWNED',
                                                  zhHans: '已拥有',
                                                  zhHant: '已擁有',
                                                )
                                              : GameLocale.select(
                                                  ko: '묶음에 포함',
                                                  en: 'INCLUDED',
                                                  zhHans: '组合内含',
                                                  zhHant: '組合內含',
                                                ),
                                          style: MosiFonts.grotesk(
                                            size: 13,
                                            weight: FontWeight.w700,
                                            color: game.isOwned
                                                ? const Color(0xFF39754C)
                                                : MosiColors.violet,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
