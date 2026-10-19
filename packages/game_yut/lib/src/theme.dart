import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_yut/src/rules.dart';
import 'package:game_yut/src/view.dart';

/// 일반판(한지·마커)과 에디션(홀로그램 민화) 색입니다.
abstract final class YutColors {
  // 한지·마커
  static const paper = Color(0xFFF3EBDC);
  static const paperLight = Color(0xFFFBF6EA);
  static const paperDeep = Color(0xFFEFE4CE);
  static const ink = Color(0xFF2E2A26);
  static const inkSoft = Color(0xFF3A3630);
  static const muted = Color(0xFF6E6A62);
  static const edge = Color(0xFF8C7158);
  static const edgeShadow = Color(0xFFBCA584);
  static const blue = Color(0xFF2B4C8C);
  static const blueDeep = Color(0xFF18305E);
  static const blueSoft = Color(0xFFEEF1F6);
  static const blueLine = Color(0xFFB4C0D6);
  static const red = Color(0xFFC21F2E);
  static const redDeep = Color(0xFF7A1019);
  static const vermilion = Color(0xFFB4453A);
  static const jade = Color(0xFF3E7D5E);
  static const grey = Color(0xFFE6E7EA);
  static const gold = Color(0xFFE8B65A);

  // 홀로그램 민화
  static const night = Color(0xFF0B0A12);
  static const nightPanel = Color(0xFF14121F);
  static const nightRaised = Color(0xFF1A1726);
  static const nightEdge = Color(0xFF3A3550);
  static const lilac = Color(0xFFC9B8FF);
  static const moon = Color(0xFFE9E2FF);
  static const haze = Color(0xFFA9A2C8);
  static const holoBlue = Color(0xFF2F4DB0);
  static const holoBlueLight = Color(0xFF3C5FD0);
  static const holo = [
    Color(0xFFC9B8FF),
    Color(0xFFA9E8F0),
    Color(0xFFF6C3DF),
    Color(0xFFD9F2E4),
    Color(0xFFB6C7FF),
    Color(0xFFF3D2F0),
  ];
  static const holoGradient = LinearGradient(
    begin: Alignment(-1, -.6),
    end: Alignment(1, .6),
    colors: holo,
    stops: [0, .24, .46, .66, .84, 1],
  );
}

abstract final class YutFonts {
  /// 제목·버튼·리본(Do Hyeon).
  static const display = 'DoHyeon';

  /// 붓글씨 명조(Song Myung): 윷 결과, 앞·뒤, 말 이름.
  static const brush = 'SongMyung';

  /// 본문(IBM Plex Sans KR).
  static const body = 'packages/game_kit/IBMPlexSansKR';

  static TextStyle title(
    double size, {
    Color color = YutColors.ink,
    double height = 1.1,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: const [body],
    fontSize: size,
    color: color,
    height: height,
    shadows: shadows,
  );

  static TextStyle stamp(
    double size, {
    Color color = YutColors.ink,
    double height = 1,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: brush,
    fontFamilyFallback: const [body],
    fontSize: size,
    color: color,
    height: height,
    shadows: shadows,
  );

  static TextStyle text(
    double size, {
    Color color = YutColors.ink,
    FontWeight weight = FontWeight.w600,
    double height = 1.3,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// 팀마다 리본·칩·말에 쓰는 색 묶음입니다.
@immutable
class YutTeamStyle {
  const YutTeamStyle({
    required this.fill,
    required this.ink,
    required this.edge,
    required this.shadow,
    required this.soft,
    required this.piece,
  });
  final Color fill;
  final Color ink;
  final Color? edge;
  final Color shadow;
  final Color soft;
  final String piece;

  static YutTeamStyle of(YutTeam? team) => switch (team) {
    YutTeam.blue || YutTeam.east => const YutTeamStyle(
      fill: YutColors.blue,
      ink: Colors.white,
      edge: null,
      shadow: YutColors.blueDeep,
      soft: YutColors.blueSoft,
      piece: 'piece_blue',
    ),
    YutTeam.south => const YutTeamStyle(
      fill: YutColors.vermilion,
      ink: Colors.white,
      edge: null,
      shadow: Color(0xFF7A2A22),
      soft: Color(0xFFF6E7E3),
      piece: 'piece_red',
    ),
    // 일반 윷놀이 자리 색(시안): 파랑 · 빨강 · 금색 · 초록.
    YutTeam.west => const YutTeamStyle(
      fill: Color(0xFFE0A93C),
      ink: Colors.white,
      edge: null,
      shadow: Color(0xFF9A6F1C),
      soft: Color(0xFFFBF0DA),
      piece: 'piece_gold',
    ),
    YutTeam.north => const YutTeamStyle(
      fill: Color(0xFF3F7A5A),
      ink: Colors.white,
      edge: null,
      shadow: Color(0xFF24503A),
      soft: Color(0xFFE4F0E9),
      piece: 'piece_green',
    ),
    _ => const YutTeamStyle(
      fill: YutColors.paperLight,
      ink: YutColors.inkSoft,
      edge: YutColors.edge,
      shadow: YutColors.edgeShadow,
      soft: YutColors.paperLight,
      piece: 'piece_white',
    ),
  };
}

String yutText(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

/// 화면 문구입니다. 네 언어를 함께 둡니다.
abstract final class YutCopy {
  static String teamName(YutTeam? team) => switch (team) {
    YutTeam.blue => yutText('청군', 'Blue', '青军', '青軍'),
    YutTeam.white => yutText('백군', 'White', '白军', '白軍'),
    YutTeam.east => yutText('동', 'East', '东', '東'),
    YutTeam.south => yutText('남', 'South', '南', '南'),
    YutTeam.west => yutText('서', 'West', '西', '西'),
    YutTeam.north => yutText('북', 'North', '北', '北'),
    null => '',
  };

  /// 말 위에 쓰는 한 글자 팀 표시입니다.
  static String teamMark(YutTeam? team) => switch (team) {
    YutTeam.blue => yutText('청', 'B', '青', '青'),
    YutTeam.white => yutText('백', 'W', '白', '白'),
    _ => teamName(team),
  };

  static String result(YutResult result) => switch (result) {
    YutResult.backDo => yutText('빽도', 'Back-do', '退道', '退道'),
    YutResult.doo => yutText('도', 'Do', '道', '道'),
    YutResult.gae => yutText('개', 'Gae', '开', '開'),
    YutResult.geol => yutText('걸', 'Geol', '杰', '傑'),
    YutResult.yut => yutText('윷', 'Yut', '柶', '柶'),
    YutResult.mo => yutText('모', 'Mo', '模', '模'),
  };

  static String steps(YutResult result) => result == YutResult.backDo
      ? yutText('1칸 뒤로', '1 back', '后退1格', '後退1格')
      : yutText(
          '${result.steps}칸',
          '${result.steps} step${result.steps == 1 ? '' : 's'}',
          '${result.steps}格',
          '${result.steps}格',
        );

  static String stepsForward(YutResult result) => result == YutResult.backDo
      ? steps(result)
      : yutText(
          '${result.steps}칸 앞으로',
          '${result.steps} forward',
          '前进${result.steps}格',
          '前進${result.steps}格',
        );

  static String get front => yutText('앞', 'Front', '正', '正');
  static String get back => yutText('뒤', 'Back', '反', '反');
  static String get start => yutText('출발', 'Start', '出发', '出發');
  static String get rules => yutText('규칙 보기', 'Rules', '规则', '規則');
  static String get settings => yutText('설정', 'Settings', '设置', '設定');
  static String get exit => yutText('나가기', 'Leave', '离开', '離開');

  static String gameTitle(String gameId) => switch (gameId) {
    'yut' => yutText('윷놀이', 'Yut Nori', '掷柶游戏', '擲柶遊戲'),
    'strategy_yut_edition' => yutText(
      '전략 윷놀이 에디션',
      'Strategy Yut Edition',
      '策略掷柶特别版',
      '策略擲柶特別版',
    ),
    _ => yutText('전략 윷놀이', 'Strategy Yut', '策略掷柶', '策略擲柶'),
  };

  static String rulesMarkdown(String gameId) => gameId == 'yut'
      ? yutText(
          '''## 이렇게 해요
- 2~4명이 각자 말 4개를 가지고 출발해요. 참가자 수에 맞춰 네 방향 자리를 사용해요.
- 내 차례에 휴대폰을 흔들면 윷가락 4개가 태블릿으로 던져져요.
- 윷·모가 나오거나 상대 말을 잡으면 한 번 더 던져요.
- 태블릿에서 말을 꾹 누르면 갈 수 있는 칸이 빛나요. 끌어다 놓으면 한 칸씩 이동해요. 남은 말은 더미에서 바로 끌어 놓아요.
- 모서리에 멈추면 다음에 지름길(대각선)로 가요.
- 빨간 표시 윷 하나만 앞면이면 빽도(1칸 뒤로)예요.
- 내 말 4개를 먼저 모두 내보내면 이겨요.''',
          '''## How to play
- Two to four players each start with four pieces and use the matching number of board seats.
- On your turn, shake your phone to throw four sticks onto the tablet.
- Yut, Mo or a capture gives you another throw.
- Press and hold a piece on the tablet to light up where it can go, then drag it there. Drag new pieces straight from your stack.
- Stopping on a corner sends the next move down the diagonal.
- Only the red-marked stick face up is Back-do (one step back).
- The first to bring all four pieces home wins.''',
          '''## 玩法
- 2至4名玩家各自带着4枚棋子出发，并按人数使用棋盘座位。
- 轮到自己时摇动手机，四根柶会掷到平板上。
- 掷出柶、模或吃掉对方棋子可再掷一次。
- 在平板上长按棋子会显示可走的格子，拖过去即可移动；新棋子直接从棋堆拖出。
- 停在角上时，下一步走对角线捷径。
- 只有红色标记的柶朝上时为退道（后退1格）。
- 最先让4枚棋子全部回家者获胜。''',
          '''## 玩法
- 2至4名玩家各自帶著4枚棋子出發，並按人數使用棋盤座位。
- 輪到自己時搖動手機，四根柶會擲到平板上。
- 擲出柶、模或吃掉對方棋子可再擲一次。
- 在平板上長按棋子會顯示可走的格子，拖過去即可移動；新棋子直接從棋堆拖出。
- 停在角上時，下一步走對角線捷徑。
- 只有紅色標記的柶朝上時為退道（後退1格）。
- 最先讓4枚棋子全部回家者獲勝。''',
        )
      : yutText(
          '''## 이렇게 해요
- 청군 2명과 백군 2명이 각 팀 말 4개로 겨뤄요.
- 매 차례 네 명 모두 휴대폰에서 윷가락 하나의 앞·뒤를 골라요. 공개 전까지 서로 볼 수 없어요.
- 네 명이 고르면 한꺼번에 공개되고 앞면 개수로 결과가 정해져요. (앞면 1개 빽도 · 2개 개 · 3개 걸 · 4개 윷 · 0개 모)
- 상대 팀도 함께 고르기 때문에 상대 차례에 결과를 막을 수 있어요.
- 윷·모가 나오거나 상대 말을 잡으면 한 번 더 골라요.
- 태블릿에서 말을 꾹 누르면 갈 수 있는 칸이 빛나요. 끌어다 놓으면 한 칸씩 이동해요. 남은 말은 더미에서 바로 끌어 놓아요.
- 팀 말 4개를 먼저 모두 내보내는 팀이 이겨요.''',
          '''## How to play
- Two players in Blue and two in White race four team pieces.
- Each turn all four players secretly pick front or back on one stick.
- When everyone has chosen, the sides are revealed together. Fronts decide the result (1 Back-do · 2 Gae · 3 Geol · 4 Yut · 0 Mo).
- The other team chooses too, so you can block their turn.
- Yut, Mo or a capture gives another round.
- Press and hold a piece on the tablet to light up where it can go, then drag it there. Drag new pieces straight from your stack.
- The first team to bring all four pieces home wins.''',
          '''## 玩法
- 青军2人与白军2人用各队4枚棋子比赛。
- 每回合四人都在手机上秘密选择一根柶的正反面。
- 四人选好后同时公开，按正面数量决定结果（1个退道 · 2个开 · 3个杰 · 4个柶 · 0个模）。
- 对方队伍也一起选择，所以可以在对方回合阻挡结果。
- 掷出柶、模或吃掉对方棋子可再来一轮。
- 在平板上长按棋子会显示可走的格子，拖过去即可移动；新棋子直接从棋堆拖出。
- 最先让本队4枚棋子全部回家的一队获胜。''',
          '''## 玩法
- 青軍2人與白軍2人用各隊4枚棋子比賽。
- 每回合四人都在手機上秘密選擇一根柶的正反面。
- 四人選好後同時公開，按正面數量決定結果（1個退道 · 2個開 · 3個傑 · 4個柶 · 0個模）。
- 對方隊伍也一起選擇，所以可以在對方回合阻擋結果。
- 擲出柶、模或吃掉對方棋子可再來一輪。
- 在平板上長按棋子會顯示可走的格子，拖過去即可移動；新棋子直接從棋堆拖出。
- 最先讓本隊4枚棋子全部回家的一隊獲勝。''',
        );
}
