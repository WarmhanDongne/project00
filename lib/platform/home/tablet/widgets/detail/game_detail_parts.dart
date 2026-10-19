// [game_detail_parts.dart] 는 태블릿 게임 상세의 '구성품' 판을 그리는 파일이다.
//
// - [Platform] : 태블릿 로비 · 게임 상세
// - [Widget] : 위에는 구성품, 아래에는 세 줄짜리 간단 규칙
//
// 즉, 긴 설명 없이 무엇이 들어 있고 어떻게 노는지 한눈에 보이게 하기 위해 필요한 파일이다.
part of 'game_detail_previews.dart';

/// 등록된 게임이면 구성품 판을, 아니면 null을 돌려줍니다.
///
/// [playerCount]는 지금 방의 참가자 수입니다. 인원에 따라 달라지는 구성품은
/// 이 값에 맞는 칸을 노란색으로 표시합니다.
Widget? buildGameParts(String gameId, {int? playerCount}) => switch (gameId) {
  'liars_poker' => _LiarParts(playerCount: playerCount),
  'final_call' => const _FinalParts(),
  'mafia' => const _MafiaParts(),
  'holdem' => const _HoldemParts(),
  'yut' => const _YutParts(strategy: false),
  'strategy_yut' => const _YutParts(strategy: true),
  'strategy_yut_edition' => const _YutParts(strategy: true, edition: true),
  _ => null,
};

//=======================구성품 공통 틀==============================
/// 구성품 한 칸입니다. [flex]는 윗줄에서 차지하는 폭의 비율입니다.
class _Part {
  const _Part({
    required this.label,
    required this.child,
    this.count,
    this.flex = 1,
  });

  final String label;
  final String? count;
  final Widget child;
  final int flex;
}

/// 간단 규칙 한 줄입니다. [title]은 두세 글자의 짧은 말, [body]는 한 문장입니다.
class _Rule {
  const _Rule(this.title, this.body);

  final String title;
  final String body;
}

/// 구성품 판의 틀입니다. 위는 구성품 카드 한 장, 아래는 규칙 세 칸입니다.
///
/// 그림은 정해진 크기로 그린 뒤 칸에 맞춰 줄이므로 어느 태블릿에서도 넘치지
/// 않습니다.
class _PartsLayout extends StatelessWidget {
  const _PartsLayout({required this.parts, required this.rules});

  final List<_Part> parts;
  final List<_Rule> rules;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _partsCard(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('구성품'),
                const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, part) in parts.indexed) ...[
                        if (i > 0) const _CellDivider(),
                        Expanded(
                          flex: part.flex,
                          child: _PartCell(part: part),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 5,
          child: _partsCard(
            delay: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('이렇게 해요'),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, rule) in rules.indexed) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: _RuleCell(number: i + 1, rule: rule),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// 카드 위쪽의 작은 제목입니다.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.localized,
    maxLines: 1,
    style: MosiFonts.sans(
      size: 13,
      weight: FontWeight.w700,
      color: MosiColors.muted,
      letterSpacing: 1,
    ),
  );
}

/// 구성품 칸 사이의 가는 세로선입니다.
class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: MosiColors.cream,
  );
}

/// 구성품 한 칸: 그림을 크게, 이름과 수량을 아래에 붙입니다.
class _PartCell extends StatelessWidget {
  const _PartCell({required this.part});

  final _Part part;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: FittedBox(fit: BoxFit.contain, child: part.child),
          ),
        ),
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              part.label.localized,
              maxLines: 1,
              style: MosiFonts.sans(
                size: 15,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            if (part.count != null) ...[
              const SizedBox(width: 6),
              _CountBadge(part.count!),
            ],
          ],
        ),
      ),
    ],
  );
}

/// 규칙 한 칸: 번호 · 짧은 제목 · 한 문장.
class _RuleCell extends StatelessWidget {
  const _RuleCell({required this.number, required this.rule});

  final int number;
  final _Rule rule;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MosiColors.navy,
          shape: BoxShape.circle,
          border: Border.all(color: MosiColors.ink, width: 2),
        ),
        child: Text(
          '$number',
          style: MosiFonts.grotesk(
            size: 14,
            color: MosiColors.white,
            height: 1,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.title.localized,
              maxLines: 1,
              style: MosiFonts.sans(
                size: 17,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              rule.body.localized,
              style: MosiFonts.sans(
                size: 14,
                color: MosiColors.navy,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 수량을 알리는 남색 알약입니다.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: MosiColors.navy,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: MosiColors.ink, width: 2),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: MosiFonts.grotesk(size: 12, color: MosiColors.white, height: 1.2),
    ),
  );
}

/// 게임 화면 바탕처럼 어두운 판입니다. 버튼·손패를 게임과 같은 색 위에 놓습니다.
Widget _darkPlate(Color color, Widget child, {EdgeInsetsGeometry? padding}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MosiColors.ink, width: 2),
      ),
      child: child,
    );

/// 카드를 부채꼴로 펼칩니다. [cards]는 왼쪽부터 놓입니다.
Widget _fan(List<Widget> cards, {double overlap = 18, double spread = 7}) {
  final mid = (cards.length - 1) / 2;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, card) in cards.indexed)
        Transform.translate(
          offset: Offset(-overlap * i + overlap * mid, (i - mid).abs() * 3),
          child: _rotated(spread * (i - mid), card),
        ),
    ],
  );
}

/// 인원별 카드 수입니다(서버 덱 구성과 같은 값).
const _liarDecks = [(2, 10), (3, 17), (4, 20), (5, 27), (6, 30)];

//=======================구성품 · 라이어스 포커==============================
class _LiarParts extends StatelessWidget {
  const _LiarParts({this.playerCount});

  final int? playerCount;

  @override
  Widget build(BuildContext context) {
    const faces = [
      ('A', '에이스', 6),
      ('K', '킹', 6),
      ('Q', '퀸', 6),
      ('JOKER', '조커', 2),
    ];
    const wheels = [(16, 4), (15, 5), (12, 11)];
    final buttons = liar.Assets.games.liarsPoker.images.button;
    final current = _liarDecks
        .where((deck) => deck.$1 == playerCount)
        .firstOrNull;

    Widget card(String face, String name, {double width = 50}) =>
        LiarsPokerCardView(
          face: LiarsCardFace.fromValue(face),
          rounded: true,
          width: width,
        );

    return _PartsLayout(
      parts: [
        _Part(
          label: '카드'.localized,
          flex: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, (face, name, n)) in faces.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Column(
                  children: [
                    _Float(
                      delay: i * .3,
                      child: SizedBox(
                        width: 64,
                        height: 88,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 8,
                              top: 0,
                              child: const LiarsPokerCardView(
                                face: LiarsCardFace.back,
                                rounded: true,
                                width: 56,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 8,
                              child: card(face, name, width: 56),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CountBadge('×$n'),
                  ],
                ),
              ],
            ],
          ),
        ),
        _Part(
          label: '인원별 카드'.localized,
          count: current == null
              ? null
              : GameLocale.select(
                  ko: '${current.$1}명 ${current.$2}장',
                  en: '${current.$1} players · ${current.$2} cards',
                  zhHans: '${current.$1} 人 · ${current.$2} 张',
                  zhHant: '${current.$1} 人 · ${current.$2} 張',
                ),
          flex: 4,
          child: _LiarDeckBars(current: current?.$1),
        ),
        _Part(
          label: '벌칙 룰렛'.localized,
          flex: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, (all, bad)) in wheels.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Column(
                  children: [
                    CustomPaint(
                      size: const Size.square(76),
                      painter: _WheelPainter(all: all, bad: bad),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$bad/$all',
                      style: MosiFonts.grotesk(
                        size: 14,
                        color: const Color(0xFFA82E40),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _Part(
          label: '버튼'.localized,
          flex: 3,
          child: Semantics(
            image: true,
            label: GameLocale.select(
              ko: 'Liar, 제출, Fold 버튼',
              en: 'LIAR, Submit, and Fold buttons',
              zhHans: 'LIAR、提交与 Fold 按钮',
              zhHant: 'LIAR、提交與 Fold 按鈕',
            ),
            excludeSemantics: true,
            child: _darkPlate(
              LiarsPokerColors.night,
              // 게임 휴대폰과 같은 버튼 그림입니다.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, (asset, name)) in [
                    (buttons.buttonLiar, 'Liar'),
                    (
                      buttons.buttonSubmit,
                      GameLocale.select(
                        ko: '제출',
                        en: 'Submit',
                        zhHans: '提交',
                        zhHant: '提交',
                      ),
                    ),
                    (buttons.buttonFold, 'Fold'),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _partsImage(
                      asset.game,
                      GameLocale.select(
                        ko: '$name 버튼',
                        en: '$name button',
                        zhHans: '$name 按钮',
                        zhHant: '$name 按鈕',
                      ),
                      width: 56,
                      height: 56,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
      rules: const [
        _Rule('카드 내기', '기준 카드(A·K·Q)라며 1~3장을 뒷면으로 내요.'),
        _Rule('LIAR!', '거짓말 같으면 외쳐요. 틀린 쪽이 룰렛을 돌려요.'),
        _Rule('끝까지 생존', '룰렛은 갈수록 불리해져요. 마지막 한 명이 승리해요.'),
      ],
    );
  }
}

/// 인원이 늘면 카드도 늘어나는 막대입니다. 지금 방 인원의 막대만 노란색입니다.
class _LiarDeckBars extends StatelessWidget {
  const _LiarDeckBars({required this.current});

  final int? current;

  @override
  Widget build(BuildContext context) {
    final most = _liarDecks.last.$2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, (players, count)) in _liarDecks.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Builder(
            builder: (context) {
              final on = players == current;
              return Column(
                key: ValueKey('liar-deck-$players'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: MosiFonts.grotesk(size: 13, color: MosiColors.navy),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 30,
                    height: 24 + 76 * count / most,
                    decoration: BoxDecoration(
                      color: on ? MosiColors.sun : MosiColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MosiColors.ink, width: 2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$players명',
                    style: MosiFonts.sans(
                      size: 12,
                      weight: on ? FontWeight.w700 : FontWeight.w400,
                      color: MosiColors.navy,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.all, required this.bad});

  final int all;
  final int bad;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const center = Offset(50, 50);
    final rect = Rect.fromCircle(center: center, radius: 46);
    final sweep = 2 * math.pi / all;
    // 칸 경계를 또렷하게: 안전 칸은 흰색·크림색을 번갈아 칠하고 선을 굵게 둡니다.
    // 빨간 칸의 자리(12시부터 시계 방향 [bad]칸)는 그대로입니다.
    final stroke = Paint()
      ..isAntiAlias = true
      ..color = MosiColors.ink
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;
    for (var i = 0; i < all; i++) {
      final start = i * sweep - math.pi / 2;
      final path = Path()
        ..moveTo(50, 50)
        ..arcTo(rect, start, sweep, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = i < bad
              ? const Color(0xFFE8231F)
              : i.isEven
              ? MosiColors.white
              : MosiColors.cream,
      );
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(
      center,
      46,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(center, 9, Paint()..color = MosiColors.ink);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.all != all || oldDelegate.bad != bad;
}

//=======================구성품 · 파이널콜==============================
class _FinalParts extends StatelessWidget {
  const _FinalParts();

  @override
  Widget build(BuildContext context) {
    const colors = ['red', 'blue', 'yellow', 'green'];

    Widget team(String label, Color color, {bool extra = false}) => Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: extra ? MosiColors.white : color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: extra ? color : MosiColors.ink, width: 2.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 2; i++)
                Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: extra ? color : MosiColors.white,
                ),
            ],
          ),
          Text(
            label,
            style: MosiFonts.sans(
              size: 12,
              weight: FontWeight.w700,
              color: extra ? color : MosiColors.white,
            ),
          ),
        ],
      ),
    );

    return _PartsLayout(
      parts: [
        _Part(
          label: '숫자 카드'.localized,
          count: GameLocale.select(
            ko: '4색 × 1~10',
            en: '4 colors × 1–10',
            zhHans: '4 色 × 1–10',
            zhHant: '4 色 × 1–10',
          ),
          flex: 6,
          child: Column(
            children: [
              for (final (row, color) in colors.indexed) ...[
                if (row > 0) const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var n = 1; n <= 10; n++) ...[
                      if (n > 1) const SizedBox(width: 3),
                      _finalCardFace(color, n, 24),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        _Part(
          label: '팀'.localized,
          count: '2:2 · 2:2:2',
          flex: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  team(
                    GameLocale.select(
                      ko: '레드',
                      en: 'Red',
                      zhHans: '红队',
                      zhHant: '紅隊',
                    ),
                    FinalCallColors.red,
                  ),
                  const SizedBox(width: 8),
                  team(
                    GameLocale.select(
                      ko: '블루',
                      en: 'Blue',
                      zhHans: '蓝队',
                      zhHant: '藍隊',
                    ),
                    FinalCallColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              team(
                GameLocale.select(
                  ko: '그린',
                  en: 'Green',
                  zhHans: '绿队',
                  zhHant: '綠隊',
                ),
                FinalCallColors.green,
                extra: true,
              ),
            ],
          ),
        ),
        _Part(
          label: '팀 하트'.localized,
          count: GameLocale.select(
            ko: '3개',
            en: '3',
            zhHans: '3 个',
            zhHant: '3 個',
          ),
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FinalCallPopHeart(color: FinalCallColors.red, size: 34),
              const SizedBox(width: 8),
              const FinalCallPopHeart(color: FinalCallColors.red, size: 34),
              const SizedBox(width: 8),
              _Float(
                child: const FinalCallPopHeart(
                  color: FinalCallColors.red,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
        _Part(
          label: '선언'.localized,
          flex: 3,
          child: Semantics(
            image: true,
            excludeSemantics: true,
            label: GameLocale.select(
              ko: 'CALL 버튼',
              en: 'CALL button',
              zhHans: 'CALL 按钮',
              zhHant: 'CALL 按鈕',
            ),
            child: FinalCallPopBox(
              color: FinalCallColors.red,
              radius: 14,
              borderWidth: 3,
              shadowDepth: 4,
              width: 120,
              height: 54,
              child: Center(
                child: Text(
                  'CALL!',
                  style: finalCallPopText(
                    22,
                    color: Colors.white,
                    shadows: finalCallPopOutline(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      rules: const [
        _Rule('점수', '손패 4장에서 같은 색 합과 같은 숫자 합 중 큰 쪽이에요.'),
        _Rule('내 차례', '카드 1장을 가져와 손패와 바꾸거나 그대로 버려요.'),
        _Rule('CALL!', '자신 있으면 선언해요. 점수가 가장 낮은 사람이 하트를 잃어요.'),
      ],
    );
  }
}

//=======================구성품 · 마피아==============================
class _MafiaParts extends StatelessWidget {
  const _MafiaParts();

  @override
  Widget build(BuildContext context) {
    final groups = [
      (
        GameLocale.select(
          ko: '시민 팀',
          en: 'Citizens',
          zhHans: '市民阵营',
          zhHant: '市民陣營',
        ),
        19,
        ['citizen', 'police', 'doctor', 'bodyguard'],
      ),
      (
        GameLocale.select(
          ko: '마피아 팀',
          en: 'Mafia',
          zhHans: '黑手党阵营',
          zhHant: '黑手黨陣營',
        ),
        15,
        ['mafia', 'mafia_boss', 'spy', 'madam'],
      ),
      (
        GameLocale.select(ko: '중립', en: 'Neutral', zhHans: '中立', zhHant: '中立'),
        9,
        ['jester', 'survivor', 'cult_leader', 'vampire'],
      ),
    ];

    Widget roleCard(String id) {
      final role = MafiaRoles.find(id)!;
      return _partsImage(
        role.card!,
        GameLocale.select(
          ko: '${role.localizedDisplayName} 역할 카드',
          en: '${role.localizedDisplayName} role card',
          zhHans: '${role.localizedDisplayName}身份牌',
          zhHant: '${role.localizedDisplayName}身分牌',
        ),
        width: 52,
        height: 76,
      );
    }

    return _PartsLayout(
      parts: [
        for (final (name, count, ids) in groups)
          _Part(
            label: name,
            count: GameLocale.select(
              ko: '$count종',
              en: '$count roles',
              zhHans: '$count 种',
              zhHant: '$count 種',
            ),
            child: _fan(
              [for (final id in ids) roleCard(id)],
              overlap: 14,
              spread: 6,
            ),
          ),
      ],
      rules: const [
        _Rule('밤', '신분별로 몰래 능력을 써요. 선택은 비공개예요.'),
        _Rule('낮', '토론한 뒤 비밀 투표로 한 명을 처형해요.'),
        _Rule('승리', '위협을 모두 없애면 시민, 수가 따라잡으면 마피아가 이겨요.'),
      ],
    );
  }
}

//=======================구성품 · 홀덤==============================
class _HoldemParts extends StatelessWidget {
  const _HoldemParts();

  @override
  Widget build(BuildContext context) {
    final suits = [
      (
        _holdemCard('a', 'spades'),
        GameLocale.select(ko: '스페이드', en: 'Spades', zhHans: '黑桃', zhHant: '黑桃'),
      ),
      (
        _holdemCard('k', 'hearts'),
        GameLocale.select(ko: '하트', en: 'Hearts', zhHans: '红桃', zhHant: '紅心'),
      ),
      (
        _holdemCard('q', 'diamonds'),
        GameLocale.select(
          ko: '다이아',
          en: 'Diamonds',
          zhHans: '方块',
          zhHant: '方塊',
        ),
      ),
      (
        _holdemCard('j', 'clubs'),
        GameLocale.select(ko: '클로버', en: 'Clubs', zhHans: '梅花', zhHant: '梅花'),
      ),
    ];

    Widget face(HoldemCardModel card, double width) =>
        HoldemCardView(card: card, width: width, layout: HoldemCardLayout.hand);

    return _PartsLayout(
      parts: [
        _Part(
          label: '카드'.localized,
          count: GameLocale.select(
            ko: '52장',
            en: '52 cards',
            zhHans: '52 张',
            zhHant: '52 張',
          ),
          flex: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, (card, name)) in suits.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Column(
                  children: [
                    _Float(
                      delay: i * .3,
                      child: SizedBox(
                        width: 60,
                        height: 82,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 6,
                              top: 0,
                              child: _holdemBackCard(52),
                            ),
                            Positioned(left: 0, top: 6, child: face(card, 52)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: MosiFonts.sans(
                        size: 12,
                        weight: FontWeight.w700,
                        color: MosiColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _Part(
          label: '시작 칩'.localized,
          count: '1,000',
          flex: 3,
          child: SizedBox(
            width: 90,
            height: 80,
            child: Stack(
              children: [
                for (var i = 0; i < 5; i++)
                  Positioned(
                    left: 20 + (i.isEven ? 0 : 4),
                    bottom: i * 9.0,
                    child: const HoldemChip(size: 40),
                  ),
              ],
            ),
          ),
        ),
        _Part(
          label: '버튼'.localized,
          flex: 4,
          child: Semantics(
            image: true,
            label: GameLocale.select(
              ko: 'Fold, Call, Raise 버튼',
              en: 'Fold, Call, and Raise buttons',
              zhHans: 'Fold、Call 与 Raise 按钮',
              zhHant: 'Fold、Call 與 Raise 按鈕',
            ),
            child: ExcludeSemantics(
              child: IgnorePointer(
                // 초록 판 대신 버튼마다 초록 그림자를 둬 흰 바탕과 구분합니다.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _puckGlow(
                      HoldemPuckButton(
                        label: 'Fold',
                        dark: true,
                        size: 52,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    _puckGlow(
                      HoldemPuckButton(
                        label: 'Call',
                        amount: '400',
                        size: 58,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    _puckGlow(
                      HoldemPuckButton(
                        label: 'Raise',
                        size: 52,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      rules: const [
        _Rule('카드 조합', '내 카드 2장과 공용 카드 5장으로 가장 강한 5장을 만들어요.'),
        _Rule('베팅', '라운드마다 폴드·콜·레이즈 등으로 팟을 겨뤄요.'),
        _Rule('토너먼트', '블라인드가 5판마다 두 배가 돼요. 마지막 한 명이 승리해요.'),
      ],
    );
  }
}

/// 퍽 버튼 둘레에 초록 그림자를 얕게 깔아 흰 바탕에서도 모양이 보이게 합니다.
Widget _puckGlow(Widget puck) => DecoratedBox(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: HoldemColors.felt.withValues(alpha: .75),
        blurRadius: 12,
        spreadRadius: 3,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: puck,
);

//=======================윷놀이 3종 구성품 판==============================
// 시안 `게임 상세 · 구성품`을 옮겼습니다: 윷판 1개, 얼굴이 들어간 윷가락 4개,
// 팀 말 더미 둘. 일반판은 네 사람의 말 네 묶음, 에디션은 홀로그램 부품입니다.
class _YutParts extends StatelessWidget {
  const _YutParts({required this.strategy, this.edition = false});

  final bool strategy;
  final bool edition;

  static const _characters = ['frog', 'cat', 'crab', 'whale'];

  @override
  Widget build(BuildContext context) {
    final board = Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: edition ? yut.YutColors.night : const Color(0xFFC98A4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: edition ? yut.YutColors.lilac : MosiColors.ink,
          width: 3,
        ),
        boxShadow: const [BoxShadow(color: _deepest, offset: Offset(5, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        // 일반·전략 윷놀이는 게임과 같은 오크 판(E안), 에디션은 홀로그램 판입니다.
        child: edition
            ? Image(image: yut.YutImages.boardHolo, fit: BoxFit.fill)
            : const yut.YutOakBoard(side: 234),
      ),
    );
    final sticks = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, angle) in [-8.0, -3.0, 3.0, 8.0].indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.rotate(
              angle: angle * math.pi / 180,
              child: yut.YutStick(
                // 일반판은 한 사람이 던지는 윷 네 개, 전략판은 사람마다 하나입니다.
                front: strategy || i != 2,
                width: 46,
                edition: edition,
                characterId: strategy ? _characters[i] : _characters.first,
                marked: !strategy && i == 0,
              ),
            ),
          ),
      ],
    );
    final teams = strategy
        ? [yut.YutTeam.blue, yut.YutTeam.white]
        : [
            yut.YutTeam.east,
            yut.YutTeam.south,
            yut.YutTeam.west,
            yut.YutTeam.north,
          ];
    final pieceSize = strategy ? 66.0 : 46.0;
    final stacks = SizedBox(
      width: strategy ? 186 : 210,
      height: strategy ? 128 : 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (t, team) in teams.indexed)
            for (final (k, dx) in [10.0, 12.0, 6.0, 16.0].indexed)
              Positioned(
                left: (strategy ? 98.0 : 52.0) * t + dx * (strategy ? 1 : .6),
                bottom: k * (strategy ? 14.0 : 11.0),
                child: yut.YutPieceToken(
                  team: team,
                  label: '',
                  size: pieceSize,
                  edition: edition,
                  characterId: strategy ? null : _characters[t],
                ),
              ),
        ],
      ),
    );
    final piecesCount = strategy
        ? GameLocale.select(
            ko: '청 4 · 백 4',
            en: 'Blue 4 · White 4',
            zhHans: '青 4 · 白 4',
            zhHant: '青 4 · 白 4',
          )
        : GameLocale.select(
            ko: '4색 · 4개씩',
            en: '4 colors · 4 each',
            zhHans: '4色 · 各4枚',
            zhHant: '4色 · 各4枚',
          );
    return _PartsLayout(
      parts: [
        _Part(
          label: GameLocale.select(
            ko: '윷판',
            en: 'Board',
            zhHans: '柶盘',
            zhHant: '柶盤',
          ),
          count: GameLocale.select(
            ko: '1개',
            en: '1',
            zhHans: '1个',
            zhHant: '1個',
          ),
          flex: 13,
          child: _Float(child: board),
        ),
        _Part(
          label: GameLocale.select(
            ko: '윷가락',
            en: 'Sticks',
            zhHans: '柶',
            zhHant: '柶',
          ),
          count: strategy
              ? GameLocale.select(
                  ko: '4개 · 1인 1개',
                  en: '4 · 1 each',
                  zhHans: '4根 · 每人1根',
                  zhHant: '4根 · 每人1根',
                )
              : GameLocale.select(
                  ko: '4개',
                  en: '4 sticks',
                  zhHans: '4根',
                  zhHant: '4根',
                ),
          flex: 10,
          child: _Float(delay: .3, child: sticks),
        ),
        _Part(
          label: GameLocale.select(
            ko: '말',
            en: 'Pieces',
            zhHans: '棋子',
            zhHant: '棋子',
          ),
          count: piecesCount,
          flex: 10,
          child: _Float(delay: .6, child: stacks),
        ),
      ],
      rules: strategy
          ? [
              _Rule(
                GameLocale.select(
                  ko: '앞·뒤 고르기',
                  en: 'Pick a side',
                  zhHans: '选正反',
                  zhHant: '選正反',
                ),
                GameLocale.select(
                  ko: '네 명이 각자 윷 하나의 앞이나 뒤를 골라요. 공개 전까지는 서로 볼 수 없어요.',
                  en: 'All four secretly pick front or back on one stick.',
                  zhHans: '四人各自秘密选择一根柶的正面或反面。',
                  zhHant: '四人各自秘密選擇一根柶的正面或反面。',
                ),
              ),
              _Rule(
                GameLocale.select(
                  ko: '동시 공개',
                  en: 'Reveal',
                  zhHans: '同时公开',
                  zhHant: '同時公開',
                ),
                GameLocale.select(
                  ko: '앞면 개수로 도·개·걸·윷·모가 정해져요. 상대 차례에도 막을 수 있어요.',
                  en: 'Fronts decide the throw. You can block the other team too.',
                  zhHans: '正面数量决定结果，也能在对方回合阻挡。',
                  zhHant: '正面數量決定結果，也能在對方回合阻擋。',
                ),
              ),
              _Rule(
                GameLocale.select(
                  ko: '말 4개 완주',
                  en: 'Bring 4 home',
                  zhHans: '4子到家',
                  zhHant: '4子到家',
                ),
                GameLocale.select(
                  ko: '팀 말 4개를 먼저 모두 내보내는 팀이 이겨요.',
                  en: 'The first team to bring all four pieces home wins.',
                  zhHans: '先让本队4枚棋子全部回家的一队获胜。',
                  zhHant: '先讓本隊4枚棋子全部回家的一隊獲勝。',
                ),
              ),
            ]
          : [
              _Rule(
                GameLocale.select(
                  ko: '흔들어 던지기',
                  en: 'Shake',
                  zhHans: '摇动投掷',
                  zhHant: '搖動投擲',
                ),
                GameLocale.select(
                  ko: '내 차례에 휴대폰을 흔들면 윷 네 개가 태블릿으로 던져져요.',
                  en: 'Shake your phone to throw four sticks onto the tablet.',
                  zhHans: '轮到自己时摇动手机，四根柶会掷到平板上。',
                  zhHant: '輪到自己時搖動手機，四根柶會擲到平板上。',
                ),
              ),
              _Rule(
                GameLocale.select(
                  ko: '한 번 더',
                  en: 'Again',
                  zhHans: '再来一次',
                  zhHant: '再來一次',
                ),
                GameLocale.select(
                  ko: '윷·모가 나오거나 상대 말을 잡으면 한 번 더 던져요.',
                  en: 'Yut, Mo or a capture earns another throw.',
                  zhHans: '掷出柶、模或吃子可再掷一次。',
                  zhHant: '擲出柶、模或吃子可再擲一次。',
                ),
              ),
              _Rule(
                GameLocale.select(
                  ko: '말 4개 완주',
                  en: 'Bring 4 home',
                  zhHans: '4子到家',
                  zhHant: '4子到家',
                ),
                GameLocale.select(
                  ko: '내 말 4개를 먼저 모두 내보내면 이겨요.',
                  en: 'Bring all four of your pieces home first to win.',
                  zhHans: '先让自己的4枚棋子全部回家即获胜。',
                  zhHant: '先讓自己的4枚棋子全部回家即獲勝。',
                ),
              ),
            ],
    );
  }
}
