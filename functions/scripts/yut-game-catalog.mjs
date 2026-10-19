/* eslint-disable max-len, require-jsdoc */

const localeMap = (ko, en, zhHans, zhHant) => Object.freeze({
  ko,
  "zh-Hans": zhHans,
  "zh-Hant": zhHant,
  en,
});

const strategyRules = localeMap(
  "4명이 2팀으로 나뉩니다. 매 차례 네 명 모두 무표식 윷 하나의 앞·뒤를 비공개로 선택해 동시에 공개하고, 앞면 수로 도·개·걸·윷·모를 정합니다. 도는 한 칸 뒤로 가는 백도입니다. 먼저 자기 팀 말 4개를 모두 완주시키면 이깁니다.",
  "Four players form two teams. Each round, all four privately choose front or back on one unmarked stick and reveal together. The number of front sides determines Do, Gae, Geol, Yut, or Mo. Do moves one step backward. The first team to finish all four pieces wins.",
  "4名玩家分为两队。每回合四人各自秘密选择一根无标记柶的正面或反面，再同时公开。正面数量决定掷柶结果，Do代表后退一步。率先完成本队全部4枚棋子的一队获胜。",
  "4名玩家分為兩隊。每回合四人各自秘密選擇一根無標記柶的正面或反面，再同時公開。正面數決定擲柶結果，Do代表後退一步。率先完成本隊全部4枚棋子的一隊獲勝。",
);

const classicRules = localeMap(
  "2~4명이 네 방향 자리에 앉아 각자 말을 움직입니다. 차례가 오면 한 명이 윷가락 4개를 함께 던집니다. 결과에 따라 말을 움직이며 빨간 표시 윷으로 백도를 판정합니다. 먼저 자기 말 4개를 모두 완주시키면 승리합니다.",
  "Two to four players take seats around the board and move their own pieces. On a turn, one player throws all four sticks together. The result determines movement; the red-marked stick identifies Back-Do. The first player to finish all four pieces wins.",
  "2至4名玩家围坐棋盘并移动自己的棋子。轮到自己时，一名玩家同时投掷四根柶。根据结果移动棋子；红色标记的柶用于判定倒退一步。率先完成自己的4枚棋子者获胜。",
  "2至4名玩家圍坐棋盤並移動自己的棋子。輪到自己時，一名玩家同時擲出四根柶。根據結果移動棋子；紅色標記的柶用於判定倒退一步。率先完成自己的4枚棋子者獲勝。",
);

const genres = (ko, en, zhHans, zhHant) => localeMap(ko, en, zhHans, zhHant);

const catalogEntry = ({
  name, localizedNames, description, localizedDescriptions, tabletDescription,
  rules, genres: legacyGenres, localizedGenres, order, minPlayers = 4, maxPlayers = 4,
}) => Object.freeze({
  name,
  localizedNames,
  description,
  localizedDescriptions,
  tabletDescription,
  rules: rules.ko,
  localizedRules: rules,
  enabled: false,
  genres: legacyGenres,
  localizedGenres,
  minPlayers,
  maxPlayers,
  playTime: 15,
  order,
  accessType: "paid",
  storeVisible: true,
  imageUrl: "",
  componentImageUrl: "",
  ruleVideoUrl: "",
});

export const yutGameCatalog = Object.freeze({
  yut: catalogEntry({
    name: "윷놀이",
    localizedNames: localeMap("윷놀이", "Yut Nori", "掷柶游戏", "擲柶遊戲"),
    description: "2~4명이 네 방향 자리에서 윷가락 네 개를 던져 말을 움직이는 전통 윷놀이입니다.",
    localizedDescriptions: localeMap(
      "2~4명이 네 방향 자리에서 윷가락 네 개를 던져 말을 움직이는 전통 윷놀이입니다.",
      "A classic Yut game for two to four players, where the active player throws all four sticks.",
      "适合2至4人的经典掷柶游戏，由当前玩家投掷四根柶。",
      "適合2至4人的經典擲柶遊戲，由目前玩家擲出四根柶。",
    ),
    tabletDescription: "한 명이 윷 4개를 던지고 네 방향의 말이 달려요. 빨간 윷은 백도를 알려줍니다.",
    rules: classicRules,
    genres: ["전통", "보드", "전략"],
    localizedGenres: genres(["전통", "보드", "전략"], ["Traditional", "Board", "Strategy"], ["传统", "棋盘", "策略"], ["傳統", "棋盤", "策略"]),
    order: 10,
    minPlayers: 2,
    maxPlayers: 4,
  }),
  strategy_yut: catalogEntry({
    name: "전략 윷놀이",
    localizedNames: localeMap("전략 윷놀이", "Strategy Yut", "策略掷柶", "策略擲柶"),
    description: "네 명이 윷 하나씩 선택해 동시에 공개하는 2팀 전략 윷놀이입니다.",
    localizedDescriptions: localeMap(
      "네 명이 윷 하나씩 선택해 동시에 공개하는 2팀 전략 윷놀이입니다.",
      "A two-team strategy game where four players choose one stick each and reveal together.",
      "四名玩家各选一根柶并同时公开，进行两队策略对决。",
      "四名玩家各選一根柶並同時公開，進行兩隊策略對決。",
    ),
    tabletDescription: "좌우 진영에서 네 명이 무표식 윷 하나의 앞·뒤를 골라 동시에 공개합니다. 도는 백도 판정입니다.",
    rules: strategyRules,
    genres: ["전통", "전략", "팀 대결"],
    localizedGenres: genres(["전통", "전략", "팀 대결"], ["Traditional", "Strategy", "Team play"], ["传统", "策略", "团队对战"], ["傳統", "策略", "團隊對戰"]),
    order: 11,
  }),
  strategy_yut_edition: catalogEntry({
    name: "전략 윷놀이 에디션",
    localizedNames: localeMap("전략 윷놀이 에디션", "Strategy Yut Edition", "策略掷柶特别版", "策略擲柶特別版"),
    description: "전략 윷놀이와 같은 규칙을 새로운 전통 미술 테마로 즐기는 에디션입니다.",
    localizedDescriptions: localeMap(
      "전략 윷놀이와 같은 규칙을 새로운 전통 미술 테마로 즐기는 에디션입니다.",
      "A new visual edition of Strategy Yut with the same rules and play.",
      "采用全新传统美术主题、规则与策略掷柶相同的特别版。",
      "採用全新傳統美術主題、規則與策略擲柶相同的特別版。",
    ),
    tabletDescription: "전략 윷놀이 규칙은 그대로, 민화와 나전 문양을 새롭게 담았습니다.",
    rules: strategyRules,
    genres: ["전통", "전략", "에디션"],
    localizedGenres: genres(["전통", "전략", "에디션"], ["Traditional", "Strategy", "Edition"], ["传统", "策略", "特别版"], ["傳統", "策略", "特別版"]),
    order: 12,
  }),
});

export const yutGameBundles = Object.freeze({
  yut_trio: Object.freeze({
    name: "윷놀이 3종 세트",
    localizedNames: localeMap("윷놀이 3종 세트", "Yut Collection", "掷柶游戏三合一", "擲柶遊戲三合一"),
    description: "윷놀이, 전략 윷놀이, 전략 윷놀이 에디션을 한 묶음으로 만나보세요.",
    localizedDescriptions: localeMap(
      "윷놀이, 전략 윷놀이, 전략 윷놀이 에디션을 한 묶음으로 만나보세요.",
      "Get Yut Nori, Strategy Yut, and Strategy Yut Edition together.",
      "一次收藏掷柶游戏、策略掷柶和策略掷柶特别版。",
      "一次收藏擲柶遊戲、策略擲柶和策略擲柶特別版。",
    ),
    gameIds: ["yut", "strategy_yut", "strategy_yut_edition"],
    order: 20,
    storeVisible: true,
  }),
});
