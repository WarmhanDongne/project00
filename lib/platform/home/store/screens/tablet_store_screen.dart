import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:math' as math;
import 'package:project00/platform/home/store/store_motion.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

import 'package:flutter/material.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';

//=======================게임 상점 (UI만)==============================
// 시안 '모시 서점(신간 매대)'과 마피아 예고편 상세입니다. 결제·구매 복원·배경 음악은
// 아직 연결되지 않았습니다. 누르면 준비 중이라고만 알립니다
// (docs/planning/NEWGUI_FEATURE_GAP.md 참고).

const _canvas = Size(1194, 834);

void _notReady(BuildContext context, [String? message]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message ?? context.l10n.purchaseNotice)),
    );
}

/// 시안 크기(1194×834)로 그린 화면을 기기 크기에 맞춰 줄이고 남는 곳은 [color]로 채웁니다.
class _DesignCanvas extends StatelessWidget {
  const _DesignCanvas({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(size: _canvas, child: child),
          ),
        ),
      ),
    );
  }
}

enum _StoreItem { liar, mafia, finalCall, soon }

class TabletStoreScreen extends StatefulWidget {
  const TabletStoreScreen({super.key, required this.gameProvider});
  final GameProvider gameProvider;

  @override
  State<TabletStoreScreen> createState() => _TabletStoreScreenState();
}

class _TabletStoreScreenState extends State<TabletStoreScreen> {
  _StoreItem _selected = _StoreItem.mafia;
  @override
  void initState() {
    super.initState();
    widget.gameProvider.addListener(_catalogChanged);
    if (widget.gameProvider.games.isEmpty && !widget.gameProvider.isLoading) {
      widget.gameProvider.fetchGames();
    }
  }

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.gameProvider.removeListener(_catalogChanged);
    super.dispose();
  }

  GameInfo? _game(_StoreItem item) {
    final id = switch (item) {
      _StoreItem.liar => 'liars_poker',
      _StoreItem.mafia => 'mafia',
      _StoreItem.finalCall => 'final_call',
      _StoreItem.soon => null,
    };
    return widget.gameProvider.games
        .where((g) => g.id == id && g.enabled)
        .firstOrNull;
  }

  String _status(_StoreItem item) {
    if (item == _StoreItem.soon) return context.l10n.comingSoon;
    if (widget.gameProvider.isLoading) return context.l10n.checking;
    if (widget.gameProvider.errorMessage != null) {
      return context.l10n.checkFailed;
    }
    final game = _game(item);
    return game?.isOwned == true
        ? context.l10n.owned
        : game?.isFree == true
        ? context.l10n.free
        : context.l10n.purchaseSoon;
  }

  void _select(_StoreItem item) => setState(() {
    _selected = item;
  });

  Future<void> _openFrame(_StoreItem item) async {
    _select(item);
    if (item != _StoreItem.mafia) return;
    final selected = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => TabletStoreMafiaDetail(game: _game(item)),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (selected != null && mounted) Navigator.of(context).pop(selected);
  }

  void _act() {
    if (widget.gameProvider.errorMessage != null) {
      widget.gameProvider.fetchGames();
      return;
    }
    if (_selected == _StoreItem.mafia) {
      _openFrame(_selected);
      return;
    }
    final game = _game(_selected);
    if (game?.isAccessible == true) {
      Navigator.of(context).pop(game!.id);
    } else {
      _notReady(
        context,
        _selected == _StoreItem.soon
            ? '새 게임 소식은 상점에서 확인해 주세요. 알림 신청은 준비 중이에요.'
            : context.l10n.purchaseNotice,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final (name, meta, description) = switch (_selected) {
      _StoreItem.mafia => (
        '마피아',
        '역할 추리 · 2026',
        '밤에는 마피아가, 낮에는 시민이 움직여요. 태블릿이 사회자가 되고, 내 역할은 내 휴대폰에만 보여요.',
      ),
      _StoreItem.liar => (
        '라이어스 포커',
        '카드 · 블러핑 · 2026',
        '카드를 내고, 거짓말이다 싶으면 LIAR를 외치세요.',
      ),
      _StoreItem.finalCall => (
        '파이널콜',
        '팀전 카드 · 2026',
        '4명은 2대2, 6명은 2대2대2 팀전이에요.',
      ),
      _StoreItem.soon => (
        '곧 나올 게임',
        '다음 신간',
        '아직 공개 전이에요. 새 게임 소식은 이곳에서 확인해 주세요.',
      ),
    };
    final chip = _status(_selected);
    final buttonLabel = widget.gameProvider.isLoading
        ? context.l10n.checkingProgress
        : widget.gameProvider.errorMessage != null
        ? context.l10n.checkAgain
        : _selected == _StoreItem.mafia
        ? context.l10n.details
        : _game(_selected)?.isAccessible == true
        ? context.l10n.playFromShelf
        : _selected == _StoreItem.soon
        ? context.l10n.releaseSoon
        : context.l10n.purchaseSoon;

    return Scaffold(
      backgroundColor: MosiColors.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final compact = width < 1000;
            final inset = compact ? 16.0 : 32.0;
            // 시안의 헤더(간판 포함)·계산대 높이입니다. 매대 위 책 영역은 남은 높이에 맞춰 줄입니다.
            final headerHeight = compact ? 84.0 : 96.0;
            const counterHeight = 168.0;
            final displayTop = inset + headerHeight;
            final displayHeight = math.max(
              0.0,
              height - counterHeight - displayTop,
            );
            final scale = math.min(
              (width - inset * 2) / _bookRow.width,
              displayHeight / _bookRow.height,
            );
            final tableHeight = 78 * scale;
            final wallBottom = counterHeight + _wallBottomRatio * 506 * scale;
            final wallTop = math.max(
              inset + 40,
              height - wallBottom - 272 * scale,
            );
            return ColoredBox(
              color: MosiColors.cream,
              child: Stack(
                children: [
                  // 뒷벽 책장
                  Positioned(
                    left: 0,
                    right: 0,
                    top: wallTop,
                    bottom: wallBottom,
                    child: const RepaintBoundary(
                      child: CustomPaint(painter: _BackShelfPainter()),
                    ),
                  ),
                  // 매대
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: counterHeight,
                    height: tableHeight,
                    child: _DisplayTable(scale: scale),
                  ),
                  // 계산대
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: counterHeight,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: MosiColors.violet,
                        border: Border(
                          top: BorderSide(color: MosiColors.ink, width: 4),
                        ),
                      ),
                    ),
                  ),
                  // 신간 매대 위 책
                  Positioned(
                    left: inset,
                    right: inset,
                    top: displayTop,
                    bottom: counterHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox.fromSize(
                        size: _bookRow,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, book) in _books.indexed)
                              _StoreBook(
                                key: ValueKey('store-book-${book.item.name}'),
                                book: book,
                                owned: _game(book.item)?.isOwned == true,
                                entranceIndex: i,
                                selected: _selected == book.item,
                                onTap: () => _select(book.item),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 헤더: 선반 · 간판 · 구매 내역 복원
                  Positioned(
                    left: inset,
                    right: inset,
                    top: 0,
                    height: inset + headerHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: inset),
                            child: StoreEntrance(
                              start: .25,
                              offset: const Offset(0, -30),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _StoreHeaderButton(
                                  label: context.l10n.shelf,
                                  icon: Icons.chevron_left_rounded,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        StoreEntrance(
                          end: .55,
                          offset: const Offset(0, -110),
                          child: _HangingSign(
                            title: context.l10n.galleryTitle,
                            stringLength: inset + 4,
                            compact: compact,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: inset),
                            child: StoreEntrance(
                              start: .25,
                              offset: const Offset(0, -30),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: _StoreHeaderButton(
                                  label: context.l10n.restorePurchases,
                                  onPressed: () => _notReady(
                                    context,
                                    context.l10n.restoreSoon,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 계산대 위 정보 카드
                  Positioned(
                    left: inset,
                    right: inset,
                    bottom: math.max(inset - 8, 12),
                    height: counterHeight - 24 - math.max(inset - 8, 12),
                    child: StoreEntrance(
                      start: .45,
                      offset: const Offset(0, 80),
                      child: _CounterCard(
                        name: name,
                        status: chip,
                        meta: meta,
                        description: description,
                        hint: width >= 1100,
                        compact: compact,
                        buttonLabel: buttonLabel,
                        onPressed: widget.gameProvider.isLoading ? null : _act,
                        locale: locale,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 시안의 책 4권 영역(좌우 60px 여백을 뺀 1074×506)입니다.
const _bookRow = Size(1074, 506);

/// 뒷벽 책장 아래 끝이 책 영역 바닥에서 떨어진 비율입니다(시안 666-390=276).
const _wallBottomRatio = 276 / 506;

class _StoreHeaderButton extends StatelessWidget {
  const _StoreHeaderButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MosiButton(
      label: label,
      onPressed: onPressed,
      background: MosiColors.white,
      foreground: MosiColors.ink,
      shadowOffset: 4,
      // 그림자 4px를 더해 로비 머리줄 버튼과 같은 44px입니다.
      height: 40,
      fontSize: 16,
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      leading: icon == null ? null : Icon(icon),
    );
  }
}

class _HangingSign extends StatelessWidget {
  const _HangingSign({
    required this.title,
    required this.stringLength,
    required this.compact,
  });

  final String title;
  final double stringLength;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    Widget string() =>
        Container(width: 3, height: stringLength, color: MosiColors.ink);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            string(),
            SizedBox(width: compact ? 90 : 120),
            string(),
          ],
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 24 : 34,
            compact ? 6 : 10,
            compact ? 24 : 34,
            compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: MosiColors.navy,
            border: Border.all(color: MosiColors.ink, width: 3),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: MosiColors.ink, offset: Offset(5, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: MosiFonts.sans(
                  locale: locale,
                  size: compact ? 22 : 30,
                  weight: FontWeight.w700,
                  color: MosiColors.cream,
                  letterSpacing: 1,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'NEW ARRIVALS · AUTUMN',
                style: MosiFonts.grotesk(
                  locale: locale,
                  size: compact ? 9 : 11,
                  weight: FontWeight.w700,
                  color: MosiColors.sun,
                  letterSpacing: compact ? 3 : 5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 뒷벽 책장: 칸 두 줄에 장식용 책등을 꽂고 아래에 나무 선반을 둡니다.
class _BackShelfPainter extends CustomPainter {
  const _BackShelfPainter();

  static const _wall = Color(0xFFE9DFCC);
  static const _wood = Color(0xFFC99A5B);
  static const _tones = [
    Color(0xFFD9D1EE),
    Color(0xFFE9DCC0),
    Color(0xFFC9DACD),
    Color(0xFFEBCFC3),
    Color(0xFFDAD6CC),
    Color(0xFFC8D0E6),
    Color(0xFFEFE5B0),
    Color(0xFFE2C9DD),
    Color(0xFFF3EEE2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 시안 272px 기준 비율입니다.
    final k = size.height / 272;
    final ink = Paint()..color = MosiColors.ink;
    canvas.drawRect(Offset.zero & size, Paint()..color = _wall);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 3), ink);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 3, size.width, 3), ink);

    final spineBorder = Paint()
      ..color = MosiColors.ink.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k;
    for (final (row, seed) in [(0, 11), (1, 37)]) {
      final plankTop = (row == 0 ? 122 : 256) * k;
      var s = seed;
      var x = 12 * k;
      var i = 0;
      while (x < size.width) {
        s = (s * 9301 + 49297) % 233280;
        final w = (18 + (s / 233280 * 20).floor()) * k;
        final h = (74 + (((s * 7) % 233280) / 233280 * 36).floor()) * k;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, plankTop - h, w, h),
          topLeft: Radius.circular(2 * k),
          topRight: Radius.circular(2 * k),
        );
        canvas.drawRRect(rect, Paint()..color = _tones[(i * 4 + seed) % 9]);
        canvas.drawRRect(rect.deflate(k), spineBorder);
        x += w + 3 * k;
        i++;
      }
      final plank = Rect.fromLTWH(0, plankTop, size.width, 12 * k);
      canvas.drawRect(plank, Paint()..color = _wood);
      canvas.drawRect(Rect.fromLTWH(0, plank.top, size.width, 3 * k), ink);
      if (row == 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, plank.bottom - 3 * k, size.width, 3 * k),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackShelfPainter oldDelegate) => false;
}

class _DisplayTable extends StatelessWidget {
  const _DisplayTable({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: MosiColors.ink, width: 3 * scale);
    return Column(
      children: [
        Container(
          height: 16 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFE2C48F),
            border: Border(top: border, bottom: border),
          ),
        ),
        Expanded(child: Container(color: const Color(0xFFC99A5B))),
      ],
    );
  }
}

class _Book {
  const _Book({
    required this.item,
    required this.label,
    required this.note,
    required this.sub,
    required this.tilt,
    required this.spineShade,
  });

  final _StoreItem item;
  final String label;
  final String note;
  final String sub;

  /// 손글씨 쪽지가 기울어진 각도(도)입니다.
  final double tilt;
  final double spineShade;
}

const _books = [
  _Book(
    item: _StoreItem.liar,
    label: '라이어스 포커',
    note: '거짓말도 실력이에요!',
    sub: '카드 · 블러핑',
    tilt: -2,
    spineShade: .22,
  ),
  _Book(
    item: _StoreItem.mafia,
    label: '마피아',
    note: '태블릿이 사회자가 돼요',
    sub: '역할 추리 · 점원 추천',
    tilt: 1.5,
    spineShade: .3,
  ),
  _Book(
    item: _StoreItem.finalCall,
    label: '파이널콜',
    note: '둘이 한 팀, 끝까지!',
    sub: '팀전 카드',
    tilt: -1,
    spineShade: .1,
  ),
  _Book(
    item: _StoreItem.soon,
    label: '곧 나올 게임',
    note: '곧 입고돼요',
    sub: '다음 신간',
    tilt: 2,
    spineShade: .12,
  ),
];

class _StoreBook extends StatelessWidget {
  const _StoreBook({
    super.key,
    required this.book,
    required this.owned,
    required this.entranceIndex,
    required this.selected,
    required this.onTap,
  });

  final _Book book;
  final bool owned;
  final int entranceIndex;
  final bool selected;
  final VoidCallback onTap;

  static const _coverSize = Size(180, 250);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final gameId = switch (book.item) {
      _StoreItem.liar => 'liars_poker',
      _StoreItem.mafia => 'mafia',
      _StoreItem.finalCall => 'final_call',
      _StoreItem.soon => null,
    };
    const radius = BorderRadius.only(
      topLeft: Radius.circular(2),
      bottomLeft: Radius.circular(2),
      topRight: Radius.circular(8),
      bottomRight: Radius.circular(8),
    );
    final cover = Container(
      width: _coverSize.width,
      height: _coverSize.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          // 책장 넘김면(흰 종이)과 그 테두리
          BoxShadow(
            color: MosiColors.ink,
            offset: Offset(5, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color(0xFFFBF8F0),
            offset: Offset(5, 4),
            spreadRadius: -1,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: MosiColors.ink, width: 3),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (gameId == null)
              const _ComingSoonCover()
            else
              FittedBox(
                fit: BoxFit.cover,
                child: MosiGameCover(gameId: gameId, width: 180, shadow: 0),
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: book.spineShade),
                  border: Border(
                    right: BorderSide(
                      color: MosiColors.ink.withValues(alpha: .5),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final bookBody = AnimatedScale(
      scale: selected ? 1.1 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedSlide(
        offset: Offset(0, selected ? -14 / 262 : 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? MosiColors.violet : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  child: cover,
                ),
                const ClipPath(
                  clipper: _StandClipper(),
                  child: SizedBox(
                    width: 130,
                    height: 12,
                    child: ColoredBox(color: MosiColors.ink),
                  ),
                ),
              ],
            ),
            if (owned) const Positioned(top: 0, right: 40, child: _Bookmark()),
          ],
        ),
      ),
    );

    return StoreEntrance(
      start: .15 + entranceIndex * .08,
      end: .7 + entranceIndex * .08,
      child: Semantics(
        button: true,
        selected: selected,
        label: book.label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                bookBody,
                const SizedBox(height: 18),
                _TapedNote(
                  note: book.note,
                  sub: book.sub,
                  tilt: book.tilt,
                  dashed: book.item == _StoreItem.soon,
                  locale: locale,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandClipper extends CustomClipper<Path> {
  const _StandClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .08, 0)
    ..lineTo(size.width * .92, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 소장 중인 게임 표지에 꽂힌 빨간 책갈피입니다.
class _Bookmark extends StatelessWidget {
  const _Bookmark({this.width = 16, this.height = 58});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, height), painter: const _BookmarkPainter());
}

class _BookmarkPainter extends CustomPainter {
  const _BookmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * .8)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = MosiColors.red);
    canvas.drawPath(
      path,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width > 12 ? 2 : 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 아직 공개되지 않은 게임 자리의 크라프트 상자 표지입니다.
class _ComingSoonCover extends StatelessWidget {
  const _ComingSoonCover();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    const tape = Color(0xFF6E4B28);
    return ColoredBox(
      color: const Color(0xFFCDA873),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 94,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: tape),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 118,
            height: 3,
            child: ColoredBox(color: tape),
          ),
          Positioned(
            left: 60,
            top: 84,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MosiColors.cream,
                shape: BoxShape.circle,
                border: Border.all(color: MosiColors.ink, width: 2.5),
              ),
              child: Text(
                '입고\n예정',
                textAlign: TextAlign.center,
                style: MosiFonts.sans(
                  locale: locale,
                  size: 15,
                  weight: FontWeight.w700,
                  color: MosiColors.ink,
                  height: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Text(
              'NEXT TITLE',
              textAlign: TextAlign.center,
              style: MosiFonts.grotesk(
                locale: locale,
                size: 9,
                weight: FontWeight.w700,
                color: const Color(0xFF5A3E1E),
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 책 아래 테이프로 붙인 점원 추천 쪽지입니다.
class _TapedNote extends StatelessWidget {
  const _TapedNote({
    required this.note,
    required this.sub,
    required this.tilt,
    required this.dashed,
    required this.locale,
  });

  final String note;
  final String sub;
  final double tilt;
  final bool dashed;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: 170,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: MosiColors.white,
        border: dashed ? null : Border.all(color: MosiColors.ink, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 시안의 손글씨(Nanum Pen Script)는 번들하지 않아 굵은 본문체로 대신합니다.
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MosiFonts.sans(
              locale: locale,
              size: 15,
              weight: FontWeight.w700,
              color: MosiColors.ink,
              height: 1.25,
            ),
          ),
          Text(
            sub,
            style: MosiFonts.sans(
              locale: locale,
              size: 11,
              color: MosiColors.muted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          if (dashed)
            MosiDashedBorder(color: MosiColors.ink, radius: 0, child: body)
          else
            body,
          Positioned(
            top: -9,
            child: Container(
              width: 44,
              height: 14,
              color: MosiColors.sun.withValues(alpha: .85),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.name,
    required this.status,
    required this.meta,
    required this.description,
    required this.hint,
    required this.compact,
    required this.buttonLabel,
    required this.onPressed,
    required this.locale,
  });

  final String name;
  final String status;
  final String meta;
  final String description;
  final bool hint;
  final bool compact;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 18 : 30, 0, compact ? 16 : 26, 0),
      decoration: BoxDecoration(
        color: MosiColors.white,
        border: Border.all(color: MosiColors.ink, width: 3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1E1470), offset: Offset(8, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            // 고른 책이 바뀌면 이전 설명은 위로 빠지고 새 설명이 아래에서
            // 올라옵니다(로비 연출 11번).
            child: AnimatedSwitcher(
              duration: MosiMotion.of(
                context,
                const Duration(milliseconds: 260),
              ),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                final entering = child.key == ValueKey(name);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, entering ? 0.35 : -0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(name),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MosiFonts.sans(
                            locale: locale,
                            size: compact ? 22 : 30,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusTag(label: status, locale: locale),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MosiFonts.sans(
                              locale: locale,
                              size: 13,
                              color: MosiColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      locale: locale,
                      size: compact ? 13 : 15,
                      color: const Color(0xFF4A4766),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: compact ? 14 : 28),
          if (hint) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.l10n.chooseFrame,
                  style: MosiFonts.sans(
                    locale: locale,
                    size: 14,
                    weight: FontWeight.w700,
                    color: MosiColors.violet,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Bookmark(width: 10, height: 16),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.ownedDot,
                      style: MosiFonts.sans(
                        locale: locale,
                        size: 13,
                        color: MosiColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 28),
          ],
          SizedBox(
            width: compact ? 160 : 236,
            child: MosiButton(
              label: buttonLabel,
              background: MosiColors.white,
              height: compact ? 54 : 62,
              radius: 10,
              shadowOffset: 5,
              fontSize: compact ? 16 : 20,
              expand: true,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.locale});

  final String label;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      decoration: BoxDecoration(
        color: MosiColors.sun,
        border: Border.all(color: MosiColors.ink, width: 2),
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(4),
          right: Radius.circular(14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: MosiColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: MosiColors.ink, width: 2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: MosiFonts.sans(
              locale: locale,
              size: 14,
              weight: FontWeight.w700,
              color: MosiColors.ink,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

//=======================마피아 예고편 상세==============================
class TabletStoreMafiaDetail extends StatefulWidget {
  const TabletStoreMafiaDetail({super.key, this.game});
  final GameInfo? game;

  @override
  State<TabletStoreMafiaDetail> createState() => _TabletStoreMafiaDetailState();
}

class _TabletStoreMafiaDetailState extends State<TabletStoreMafiaDetail>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF0A0D12);
  static const _red = Color(0xFFFF4D4D);

  late final AnimationController _trailer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _trailer.dispose();
    _loop.dispose();
    super.dispose();
  }

  String _face(int index) => roomCharacters[index % roomCharacters.length].id;

  @override
  Widget build(BuildContext context) {
    return _DesignCanvas(
      color: _bg,
      child: ColoredBox(
        color: _bg,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 600,
              child: Image.asset(
                'assets/images/backgrounds/store_mafia_trailer.webp',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 600,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xEB0A0D12),
                      Color(0x8C0A0D12),
                      Color(0x330A0D12),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 72,
              child: ColoredBox(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      _LetterboxButton(
                        label: '‹ 상점',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'NOW SHOWING · 예고편',
                        style: const TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 22,
                          letterSpacing: 6,
                          color: Color(0xFFE8EEF5),
                        ),
                      ),
                      const Spacer(),
                      _LetterboxButton(
                        label: context.l10n.restorePurchases,
                        onPressed: () =>
                            _notReady(context, context.l10n.restoreSoon),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 56,
              top: 104,
              width: 384,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MAFIA',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 20,
                      letterSpacing: 8,
                      color: _red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '마피아',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 70,
                      weight: FontWeight.w700,
                      color: MosiColors.white,
                      letterSpacing: -3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '오늘 밤, 이 테이블 누군가는\n거짓말을 하고 있다.',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 19,
                      weight: FontWeight.w600,
                      color: const Color(0xFFE8EEF5),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '밤에는 휴대폰으로 몰래 능력을 쓰고, 낮에는 토론한 뒤 비밀 투표로 '
                    '한 명을 골라요. 사회는 태블릿이 봐요.',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 14,
                      color: const Color(0xFFC9D2DD),
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in const ['4–12명', '역할 43종', '태블릿 사회자'])
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0x99FFFFFF),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: MosiFonts.sans(
                              locale: Localizations.maybeLocaleOf(context),
                              size: 13,
                              weight: FontWeight.w600,
                              color: MosiColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 56,
              top: 470,
              width: 384,
              height: 84,
              child: _BgmCard(
                playing: false,
                animation: _loop,
                onToggle: () => _notReady(context, '예고편 음악은 준비 중이에요.'),
              ),
            ),
            Positioned(
              left: 480,
              top: 104,
              width: 660,
              height: 440,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MosiColors.ink, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 60,
                      offset: Offset(0, 30),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _trailer,
                  builder: (context, _) =>
                      _Trailer(pct: _trailer.value * 100, face: _face),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 250,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 26,
                ),
                decoration: const BoxDecoration(
                  color: MosiColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border(
                    top: BorderSide(color: MosiColors.ink, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: Row(
                        children: [
                          const MosiGameCover(
                            gameId: 'mafia',
                            width: 120,
                            shadow: 6,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '마피아',
                                      style: MosiFonts.sans(
                                        locale: Localizations.maybeLocaleOf(
                                          context,
                                        ),
                                        size: 26,
                                        weight: FontWeight.w700,
                                        color: MosiColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const MosiPill(
                                      label: 'NEW',
                                      color: MosiColors.white,
                                      background: MosiColors.red,
                                      borderColor: MosiColors.ink,
                                      fontSize: 11,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '밤에는 마피아가, 낮에는 시민이 움직여요. 태블릿이 사회자가 돼요.',
                                  style: MosiFonts.sans(
                                    locale: Localizations.maybeLocaleOf(
                                      context,
                                    ),
                                    size: 13,
                                    color: MosiColors.muted,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: Color(0xFFE4E1EE),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '구성품 · 역할 카드 43종',
                              style: MosiFonts.sans(
                                locale: Localizations.maybeLocaleOf(context),
                                size: 14,
                                weight: FontWeight.w700,
                                color: MosiColors.navy,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (final (role, color) in const [
                                  ('시민', MosiColors.sky),
                                  ('경찰', MosiColors.sky),
                                  ('의사', MosiColors.sky),
                                  ('마피아', Color(0xFFFF0000)),
                                  ('스파이', Color(0xFFFF0000)),
                                  ('광대', MosiColors.sun),
                                ]) ...[
                                  _RoleChip(name: role, color: color),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  '+37',
                                  style: MosiFonts.grotesk(
                                    locale: Localizations.maybeLocaleOf(
                                      context,
                                    ),
                                    size: 16,
                                    color: const Color(0xFF8C8AA8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '시민 19 · 마피아 15 · 중립 9 · 비밀 투표 · 밤낮 진행',
                              style: MosiFonts.sans(
                                locale: Localizations.maybeLocaleOf(context),
                                size: 12,
                                color: MosiColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 250,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.game?.isOwned == true
                                ? context.l10n.owned
                                : widget.game?.isFree == true
                                ? context.l10n.free
                                : context.l10n.purchaseSoon,
                            style: MosiFonts.grotesk(
                              locale: Localizations.maybeLocaleOf(context),
                              size: 30,
                              color: MosiColors.navy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          MosiButton(
                            label: widget.game?.isAccessible == true
                                ? context.l10n.playFromShelf
                                : context.l10n.purchaseSoon,
                            background: MosiColors.red,
                            foreground: MosiColors.white,
                            height: 60,
                            fontSize: 18,
                            radius: 12,
                            shadowOffset: 5,
                            expand: true,
                            onPressed: () => widget.game?.isAccessible == true
                                ? Navigator.of(context).pop('mafia')
                                : _notReady(context),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '구매·복원 기능은 준비 중이에요',
                            style: MosiFonts.sans(
                              locale: Localizations.maybeLocaleOf(context),
                              size: 11,
                              color: const Color(0xFF8C8AA8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterboxButton extends StatelessWidget {
  const _LetterboxButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MosiButton(
      label: label,
      onPressed: onPressed,
      variant: MosiButtonVariant.outline,
      foreground: MosiColors.white,
      height: 42,
      fontSize: 15,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 70,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MosiColors.ink, width: 2.5),
      ),
      child: Column(
        children: [
          Container(height: 22, color: color),
          const Spacer(),
          Text(
            name,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 10,
              weight: FontWeight.w700,
              color: MosiColors.ink,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _BgmCard extends StatelessWidget {
  const _BgmCard({
    required this.playing,
    required this.animation,
    required this.onToggle,
  });

  final bool playing;
  final Animation<double> animation;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xC70A0D12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x38FFFFFF), width: 1.5),
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final seconds = animation.value * 12;
          return Row(
            children: [
              Transform.rotate(
                angle: playing ? seconds / 4 * 2 * math.pi : 0,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF111111),
                        Color(0xFF1E242C),
                        Color(0xFF111111),
                        Color(0xFF1E242C),
                        Color(0xFF111111),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4D),
                      shape: BoxShape.circle,
                      border: Border.all(color: MosiColors.ink, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          playing ? '배경 음악 · 재생 중' : '배경 음악 · 준비 중',
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 11,
                            weight: FontWeight.w700,
                            color: playing
                                ? MosiColors.lime
                                : const Color(0xFF9AA6B5),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 12,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final delay in const [
                                0.0,
                                0.2,
                                0.4,
                                0.1,
                                0.3,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Container(
                                    width: 3,
                                    height:
                                        12 *
                                        (playing
                                            ? 0.3 +
                                                  0.7 *
                                                      math
                                                          .sin(
                                                            ((seconds + delay) %
                                                                    1) *
                                                                math.pi,
                                                          )
                                                          .abs()
                                            : 0.3),
                                    decoration: BoxDecoration(
                                      color: MosiColors.lime,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '밤의 골목 · 마피아 테마',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MosiFonts.sans(
                        locale: Localizations.maybeLocaleOf(context),
                        size: 15,
                        weight: FontWeight.w700,
                        color: MosiColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                toggled: playing,
                label: playing ? '배경 음악 멈추기' : '배경 음악 켜기',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: MosiColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: MosiColors.ink, width: 2),
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFF0A0D12),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 12초 예고편: 장면 네 개가 차례로 바뀝니다.
class _Trailer extends StatelessWidget {
  const _Trailer({required this.pct, required this.face});

  final double pct;
  final String Function(int index) face;

  double _kf(List<(double, double)> stops) {
    if (pct <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      if (pct <= stops[i].$1) {
        final (p0, v0) = stops[i - 1];
        final (p1, v1) = stops[i];
        if (p1 == p0) return v1;
        return v0 + (v1 - v0) * Curves.ease.transform((pct - p0) / (p1 - p0));
      }
    }
    return stops.last.$2;
  }

  Widget _scene(double opacity, double scale, Widget child) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      ),
    ),
  );

  Widget _caption(BuildContext context, String text, {bool dark = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xBF000000) : const Color(0xB3000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 17,
            weight: FontWeight.w600,
            color: MosiColors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f1o = _kf([(22, 1), (25, 0), (97, 0), (100, 1)]);
    final f1s = _kf([(22, 1), (25, 1.04), (97, 1.04), (100, 1)]);
    final f2o = _kf([(22, 0), (25, 1), (47, 1), (50, 0)]);
    final f2s = _kf([(22, 0.97), (25, 1), (47, 1), (50, 1.04)]);
    final f3o = _kf([(47, 0), (50, 1), (72, 1), (75, 0)]);
    final f3s = _kf([(47, 0.97), (50, 1), (72, 1), (75, 1.04)]);
    final f4o = _kf([(72, 0), (75, 1), (97, 1), (100, 0)]);
    final f4s = _kf([(72, 0.97), (75, 1)]);
    final aimPct = (pct * 12 / 3) % 1 * 100;
    final aimY = aimPct <= 30
        ? 0.0
        : aimPct >= 45
        ? 40.0
        : 40 * (aimPct - 30) / 15;
    final eyeOn = !(aimPct > 90 && aimPct < 98);

    return Stack(
      children: [
        _scene(
          f1o,
          f1s,
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.9,
                colors: [Color(0xFF1F2A3A), Color(0xFF0A0D12)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 330,
                  height: 214,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MosiColors.ink,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x2EFFC400), blurRadius: 60),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10131A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _Moon(size: 44),
                        const SizedBox(height: 8),
                        Text(
                          '밤이 되었습니다',
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 22,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _caption(context, '"모두 고개를 숙여 주세요."'),
              ],
            ),
          ),
        ),
        _scene(
          f2o,
          f2s,
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.9,
                colors: [Color(0xFF3A1418), Color(0xFF0A0D12)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 280,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MosiColors.ink,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Container(
                        padding: const EdgeInsets.only(top: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2A3A),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '마피아 · 나만 보여요',
                                  style: MosiFonts.sans(
                                    locale: Localizations.maybeLocaleOf(
                                      context,
                                    ),
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFFFF8A8A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '누구를 고를까요?',
                                  style: MosiFonts.sans(
                                    locale: Localizations.maybeLocaleOf(
                                      context,
                                    ),
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: MosiColors.white,
                                  ),
                                ),
                                for (final (i, (who, name)) in const [
                                  (1, '사라'),
                                  (8, '민준'),
                                  (18, '하린'),
                                ].indexed) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 112,
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: i == 1
                                          ? const Color(0x40FF4D4D)
                                          : const Color(0x14FFFFFF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: i == 1
                                            ? const Color(0xFFFF4D4D)
                                            : const Color(0x33FFFFFF),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        MosiFace(
                                          characterId: face(who),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          name,
                                          style: MosiFonts.sans(
                                            locale: Localizations.maybeLocaleOf(
                                              context,
                                            ),
                                            size: 12,
                                            weight: FontWeight.w700,
                                            color: MosiColors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Positioned(
                              right: 6,
                              top: 70 + aimY,
                              child: const Icon(
                                Icons.gps_fixed_rounded,
                                size: 34,
                                color: Color(0xFFFF4D4D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Opacity(
                      opacity: eyeOn ? 1 : 0,
                      child: Row(
                        children: [
                          for (var i = 0; i < 2; i++) ...[
                            if (i > 0) const SizedBox(width: 14),
                            Container(
                              width: 26,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF0000),
                                borderRadius: BorderRadius.all(
                                  Radius.elliptical(13, 6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFF0000),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _caption(context, '"내 역할은 내 휴대폰에만."'),
              ],
            ),
          ),
        ),
        _scene(
          f3o,
          f3s,
          ColoredBox(
            color: const Color(0xFFFFC400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'DAY 2',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 26,
                    letterSpacing: 8,
                    color: MosiColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '아침이 밝았어요',
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 34,
                    weight: FontWeight.w700,
                    color: MosiColors.ink,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                MosiBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  radius: 12,
                  shadowOffset: 5,
                  shadowColor: MosiColors.ink,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.55,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: MosiFace(characterId: face(8), size: 40),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '민준 님이 밤사이 사라졌어요',
                        style: MosiFonts.sans(
                          locale: Localizations.maybeLocaleOf(context),
                          size: 16,
                          weight: FontWeight.w700,
                          color: MosiColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _caption(context, '"자, 누가 거짓말을 하고 있죠?"', dark: true),
              ],
            ),
          ),
        ),
        _scene(
          f4o,
          f4s,
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.95,
                colors: [Color(0xFF24314A), Color(0xFF0A0D12)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SECRET VOTE',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 24,
                    letterSpacing: 8,
                    color: Color(0xFFE8EEF5),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, (who, name, votes)) in const [
                      (1, '사라', 0),
                      (18, '하린', 3),
                      (0, '지우', 1),
                      (2, '도윤', 0),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 18),
                      MosiBox(
                        width: 96,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        color: votes == 3
                            ? const Color(0xFFFF4D4D)
                            : MosiColors.cream,
                        radius: 12,
                        shadowOffset: 4,
                        shadowColor: Colors.black,
                        child: Column(
                          children: [
                            MosiFace(characterId: face(who), size: 52),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: MosiFonts.sans(
                                locale: Localizations.maybeLocaleOf(context),
                                size: 14,
                                weight: FontWeight.w700,
                                color: votes == 3
                                    ? MosiColors.white
                                    : MosiColors.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$votes표',
                              style: MosiFonts.grotesk(
                                locale: Localizations.maybeLocaleOf(context),
                                size: 18,
                                color: votes == 3
                                    ? MosiColors.white
                                    : MosiColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                _caption(context, '"과연, 하린은 마피아였을까요?"'),
              ],
            ),
          ),
        ),
        // 진행 막대
        Positioned(
          left: 16,
          right: 16,
          top: 14,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 4,
                      color: const Color(0x40FFFFFF),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ((pct - i * 25) / 25).clamp(0.0, 1.0),
                        child: Container(color: MosiColors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Moon extends StatelessWidget {
  const _Moon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MoonPainter()),
    );
  }
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 34;
    canvas.drawCircle(
      Offset(17 * s, 17 * s),
      13 * s,
      Paint()..color = const Color(0xFFFFC400),
    );
    canvas.drawCircle(
      Offset(23 * s, 12 * s),
      12 * s,
      Paint()..color = const Color(0xFF10131A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
