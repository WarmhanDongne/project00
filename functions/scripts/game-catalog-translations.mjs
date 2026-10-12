/* eslint-disable max-len */

export const gameCatalogLocales = Object.freeze([
  "ko",
  "en",
  "zh-Hans",
  "zh-Hant",
]);

export const localizedGameDescriptions = Object.freeze({
  liars_poker: Object.freeze({
    ko: "카드를 내고, 거짓말이다 싶으면 LIAR를 외치세요.",
    en: "Play a card face down and call LIAR when you think someone is bluffing.",
    "zh-Hans": "盖着出牌；如果你认为对方在说谎，就喊出 LIAR。",
    "zh-Hant": "蓋牌出牌；如果你認為對方在說謊，就喊出 LIAR。",
  }),
  final_call: Object.freeze({
    ko: "같은 색이나 숫자의 조합으로 점수를 겨루고, 이길 것 같으면 CALL을 외치는 팀전 카드 게임이에요.",
    en: "Build a high-scoring set by color or number, then call when your team is ready to win.",
    "zh-Hans": "用同色或同数字组合争取高分，在团队准备好取胜时喊出 CALL。",
    "zh-Hant": "用同色或同數字組合爭取高分，在團隊準備好獲勝時喊出 CALL。",
  }),
  mafia: Object.freeze({
    ko: "밤에는 몰래 능력을 쓰고 낮에는 토론과 투표로 마피아를 찾아요.",
    en: "Use secret abilities at night, then discuss and vote during the day to find the Mafia.",
    "zh-Hans": "夜晚秘密使用能力，白天通过讨论和投票找出黑手党。",
    "zh-Hant": "夜晚秘密使用能力，白天透過討論和投票找出黑手黨。",
  }),
  holdem: Object.freeze({
    ko: "내 카드 2장과 공용 카드 5장으로 가장 강한 포커 조합을 만들어요.",
    en: "Make the strongest poker hand using your two hole cards and five community cards.",
    "zh-Hans": "使用两张底牌和五张公共牌组成最强的扑克手牌。",
    "zh-Hant": "使用兩張底牌和五張公共牌組成最強的撲克牌型。",
  }),
});

export const localizedGameGenres = Object.freeze({
  liars_poker: Object.freeze({
    ko: Object.freeze(["카드", "블러핑"]),
    en: Object.freeze(["Cards", "Bluffing"]),
    "zh-Hans": Object.freeze(["卡牌", "诈唬"]),
    "zh-Hant": Object.freeze(["卡牌", "詐唬"]),
  }),
  final_call: Object.freeze({
    ko: Object.freeze(["카드", "팀전"]),
    en: Object.freeze(["Cards", "Team"]),
    "zh-Hans": Object.freeze(["卡牌", "团队"]),
    "zh-Hant": Object.freeze(["卡牌", "團隊"]),
  }),
  mafia: Object.freeze({
    ko: Object.freeze(["역할", "추리"]),
    en: Object.freeze(["Roles", "Deduction"]),
    "zh-Hans": Object.freeze(["角色", "推理"]),
    "zh-Hant": Object.freeze(["角色", "推理"]),
  }),
  holdem: Object.freeze({
    ko: Object.freeze(["카드", "베팅"]),
    en: Object.freeze(["Cards", "Betting"]),
    "zh-Hans": Object.freeze(["卡牌", "下注"]),
    "zh-Hant": Object.freeze(["卡牌", "下注"]),
  }),
});

// Korean remains in update-game-rules.mjs as the legacy Firestore value.
export const translatedGameRules = Object.freeze({
  liars_poker: Object.freeze({
    en: `- Components: 20 cards—six Kings, six Queens, six Aces, and two Jokers. Each player receives five cards at the start.
- Play: Place a card face down that matches the key rank for the round.
- Bluffing: If you do not have the key rank, you may play another card as a bluff. Jokers are wild.
- Challenge: Call LIAR when you believe the previous player lied, then reveal the card.
- If it was a bluff, the player who played the card spins the roulette. If it was truthful, the challenger spins.
- Landing on black means survival; landing on red means death. Each player gets up to three chances. The red area grows after every attempt, and on the third attempt every space except one is red.`,
    "zh-Hans": `- 牌组：使用6张K、6张Q、6张A和2张Joker，共20张牌。游戏开始时每人获得5张牌。
- 出牌：按照本轮指定的关键点数，盖着打出一张牌。
- 诈唬：没有关键点数时可以用其他牌冒充；Joker可作为任意牌。
- 质疑：认为上一位玩家在说谎时喊出 LIAR，并翻开该牌。
- 如果确实是诈唬，出牌者转动轮盘；如果说的是真话，质疑者转动轮盘。
- 停在黑色区域即可生存，停在红色区域则死亡。每人最多有三次机会；每次尝试后红色区域都会扩大，第三次只剩一个黑色格。`,
    "zh-Hant": `- 牌組：使用6張K、6張Q、6張A和2張Joker，共20張牌。遊戲開始時每人獲得5張牌。
- 出牌：依照本輪指定的關鍵點數，蓋著打出一張牌。
- 詐唬：沒有關鍵點數時可以用其他牌冒充；Joker可作為任意牌。
- 質疑：認為上一位玩家在說謊時喊出 LIAR，並翻開該牌。
- 如果確實是詐唬，出牌者轉動輪盤；如果說的是真話，質疑者轉動輪盤。
- 停在黑色區域即可生存，停在紅色區域則死亡。每人最多有三次機會；每次嘗試後紅色區域都會擴大，第三次只剩一個黑色格。`,
  }),
  holdem: Object.freeze({
    en: `🃏 Basic Rules

[Goal]
- Make the strongest five-card hand from your two hole cards and five community cards.
- The last player with chips wins the tournament.

[Play]
- On the preflop, flop, turn, and river, choose fold, check, call, bet, raise, or all-in.
- You have 20 seconds to act. The game checks automatically when possible and folds otherwise.
- If two or more players remain, hands and kickers are compared at showdown. If only one player remains, that player wins the pot immediately.

[Blinds and Elimination]
- Every player starts with 1,000 chips.
- Blinds begin at 10/20 and double every five hands, up to 160/320.
- A player with zero chips is eliminated. There are no rebuys.`,
    "zh-Hans": `🃏 基本规则

[游戏目标]
- 使用两张底牌和五张公共牌组成最强的五张牌组合。
- 最后仍持有筹码的玩家赢得锦标赛。

[游戏流程]
- 在翻牌前、翻牌、转牌和河牌阶段选择弃牌、过牌、跟注、下注、加注或全下。
- 行动限时20秒；可以过牌时自动过牌，否则自动弃牌。
- 剩余两人以上时在摊牌阶段比较牌型和踢脚牌；只剩一人时立即获得底池。

[盲注与淘汰]
- 每位玩家以1,000筹码开始。
- 盲注从10/20开始，每5手翻倍，最高为160/320。
- 筹码归零即淘汰，不能重新买入。`,
    "zh-Hant": `🃏 基本規則

[遊戲目標]
- 使用兩張底牌和五張公共牌組成最強的五張牌組合。
- 最後仍持有籌碼的玩家贏得錦標賽。

[遊戲流程]
- 在翻牌前、翻牌、轉牌和河牌階段選擇棄牌、過牌、跟注、下注、加注或全下。
- 行動限時20秒；可以過牌時自動過牌，否則自動棄牌。
- 剩餘兩人以上時在攤牌階段比較牌型和踢腳牌；只剩一人時立即獲得底池。

[盲注與淘汰]
- 每位玩家以1,000籌碼開始。
- 盲注從10/20開始，每5手加倍，最高為160/320。
- 籌碼歸零即淘汰，不能重新買入。`,
  }),
  mafia: Object.freeze({
    en: `🌙 Basic Rules

[Goal]
- Citizens win by finding and eliminating every Mafia member.
- The Mafia wins when the number of surviving Mafia members is at least the number of surviving citizens.

[Day]
- All survivors discuss freely, then secretly vote for one player.
- The player with the most votes is eliminated immediately and their role is revealed to everyone.
- If the highest vote is tied, nobody is eliminated.

[Night]
- Roles with abilities act simultaneously while citizens wait.
- Mafia attacks and citizen protection or investigation resolve before the result is announced in the morning.
- Eliminated players become spectators and can see every player's role.

[Citizen Roles]
- Citizen: Has no special ability and must identify the Mafia through discussion and voting.
- Police: Investigates one player each night to learn whether they are Mafia.
- Doctor: Protects one player each night from a Mafia attack.
- Bodyguard: In the current version, protects one player in the same way as the Doctor.

[Mafia Roles]
- Mafia: Chooses one citizen to eliminate each night and knows the other Mafia members from the start.
- Mafia Boss: Acts like the Mafia but appears as a citizen to Police investigations.`,
    "zh-Hans": `🌙 基本规则

[游戏目标]
- 市民阵营：找出并处决所有黑手党即可获胜。
- 黑手党阵营：存活的黑手党人数不少于存活的市民人数时获胜。

[白天]
- 所有存活玩家自由讨论，然后秘密投票给一名玩家。
- 得票最多的玩家立即被处决，其身份向所有人公开。
- 最高票出现平局时无人被处决。

[夜晚]
- 拥有能力的身份同时行动，市民等待。
- 黑手党的攻击以及市民阵营的保护、调查结算后，于早晨公布结果。
- 死亡玩家成为观战者，并可查看所有玩家的身份。

[市民阵营身份]
- 市民：没有特殊能力，需要通过讨论和投票找出黑手党。
- 警察：每晚调查一名玩家，确认其是否为黑手党。
- 医生：每晚保护一名玩家免受黑手党攻击。
- 保镖：当前版本中与医生一样保护一名玩家。

[黑手党阵营身份]
- 黑手党：每晚指定一名市民将其淘汰，并从游戏开始就知道其他黑手党成员。
- 黑手党首领：行动与黑手党相同，但警察调查时会显示为市民。`,
    "zh-Hant": `🌙 基本規則

[遊戲目標]
- 市民陣營：找出並處決所有黑手黨即可獲勝。
- 黑手黨陣營：存活的黑手黨人數不少於存活的市民人數時獲勝。

[白天]
- 所有存活玩家自由討論，然後秘密投票給一名玩家。
- 得票最多的玩家立即被處決，其身分向所有人公開。
- 最高票出現平手時無人被處決。

[夜晚]
- 擁有能力的身分同時行動，市民等待。
- 黑手黨的攻擊以及市民陣營的保護、調查結算後，於早晨公布結果。
- 死亡玩家成為觀戰者，並可查看所有玩家的身分。

[市民陣營身分]
- 市民：沒有特殊能力，需要透過討論和投票找出黑手黨。
- 警察：每晚調查一名玩家，確認其是否為黑手黨。
- 醫生：每晚保護一名玩家免受黑手黨攻擊。
- 保鑣：目前版本中與醫生一樣保護一名玩家。

[黑手黨陣營身分]
- 黑手黨：每晚指定一名市民將其淘汰，並從遊戲開始就知道其他黑手黨成員。
- 黑手黨首領：行動與黑手黨相同，但警察調查時會顯示為市民。`,
  }),
  final_call: Object.freeze({
    en: `🃏 Basic Rules

[Goal]
- Final Call is a team game for four players in two teams, or six players in three teams.
- Players sitting opposite each other are teammates. Teams are Red and Blue, with Green added in a six-player game.
- Everyone starts with three hearts. When either teammate loses every heart, both teammates are eliminated and become spectators.

[Cards and Score]
- The deck has 40 cards numbered 1–10 in four colors. Each player receives four cards.
- Your score is the higher of the sum of cards in one color or the sum of cards with one number.
- For the final submission, select one to four cards from your hand to score.

[Turns]
- On your turn, take one card from the deck or the face-up discard pile.
- Exchange it for one card in your hand or discard the drawn card unchanged.
- Each action and final submission has a 30-second limit.

[Calling]
- You may call before drawing a card on your turn.
- After the caller submits a final set, every other player gets one last exchange and then submits a final set.
- When all submissions are complete, the selected cards and scores are revealed.

[Round Result]
- The lowest-scoring player loses one heart. If the caller finishes last, the caller loses two hearts.
- If several players tie for last, all of them lose hearts.
- If the caller submits four cards of the same number, every surviving opponent loses one heart without comparing scores.
- If the deck runs out, the server automatically selects each player's best scoring set and resolves the round.

[Next Round and Victory]
- A surviving player who lost a heart in the previous round starts the next round.
- If several players qualify, the player with the fewest hearts starts; remaining ties use seat order.
- Play continues after a team is eliminated. The last surviving team wins. If all remaining teams are eliminated together, the game is a draw.`,
    "zh-Hans": `🃏 基本规则

[游戏目标]
- Final Call 是团队卡牌游戏：4人分为2队，或6人分为3队。
- 相对而坐的玩家为队友，队伍分为红队、蓝队；6人游戏还会加入绿队。
- 所有人以3颗心开始。任一队员失去全部心时，两名队员都被淘汰并进入观战。

[卡牌与分数]
- 牌组由4种颜色、数字1至10的40张牌组成，每位玩家获得4张牌。
- 分数取同色牌数字总和与同数字牌总和中的较高值。
- 最终提交时，从手牌中选择1至4张用于计分。

[回合流程]
- 自己的回合从牌堆或正面朝上的弃牌堆拿取一张牌。
- 用拿到的牌替换一张手牌，或直接弃掉拿到的牌。
- 每个动作和最终提交的限时均为30秒。

[CALL宣言]
- 自己的回合在拿牌前可以宣布 CALL。
- 宣言者提交最终组合后，其他玩家各进行最后一次换牌，再提交最终组合。
- 所有人提交后，公开所选卡牌和分数。

[回合判定]
- 最低分玩家失去1颗心；如果CALL宣言者排名最后，则失去2颗心。
- 多人并列最后时，这些玩家都会失去心。
- CALL宣言者提交4张相同数字的牌时，无需比较分数，所有仍存活的对手各失去1颗心。
- 牌堆耗尽时，服务器自动为每位玩家选择最高分组合并判定回合。

[下一回合与胜利]
- 上一回合失去心且仍存活的玩家开始下一回合。
- 候选人有多人时，剩余心最少者优先，再按座位顺序决定。
- 队伍被淘汰后其余队伍继续游戏，最后存活的队伍获胜。如果剩余队伍同时全部淘汰，则为平局。`,
    "zh-Hant": `🃏 基本規則

[遊戲目標]
- Final Call 是團隊卡牌遊戲：4人分為2隊，或6人分為3隊。
- 相對而坐的玩家為隊友，隊伍分為紅隊、藍隊；6人遊戲還會加入綠隊。
- 所有人以3顆心開始。任一隊員失去全部心時，兩名隊員都被淘汰並進入觀戰。

[卡牌與分數]
- 牌組由4種顏色、數字1至10的40張牌組成，每位玩家獲得4張牌。
- 分數取同色牌數字總和與同數字牌總和中的較高值。
- 最終提交時，從手牌中選擇1至4張用於計分。

[回合流程]
- 自己的回合從牌堆或正面朝上的棄牌堆拿取一張牌。
- 用拿到的牌替換一張手牌，或直接棄掉拿到的牌。
- 每個動作和最終提交的限時均為30秒。

[CALL宣言]
- 自己的回合在拿牌前可以宣布 CALL。
- 宣言者提交最終組合後，其他玩家各進行最後一次換牌，再提交最終組合。
- 所有人提交後，公開所選卡牌和分數。

[回合判定]
- 最低分玩家失去1顆心；如果CALL宣言者排名最後，則失去2顆心。
- 多人並列最後時，這些玩家都會失去心。
- CALL宣言者提交4張相同數字的牌時，無需比較分數，所有仍存活的對手各失去1顆心。
- 牌堆耗盡時，伺服器自動為每位玩家選擇最高分組合並判定回合。

[下一回合與勝利]
- 上一回合失去心且仍存活的玩家開始下一回合。
- 候選人有多人時，剩餘心最少者優先，再按座位順序決定。
- 隊伍被淘汰後其餘隊伍繼續遊戲，最後存活的隊伍獲勝。如果剩餘隊伍同時全部淘汰，則為平局。`,
  }),
});
