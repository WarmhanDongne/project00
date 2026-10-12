import 'package:game_kit/localization/game_locale.dart';

/// 서비스 플레이 방식 안내(홈 → 전체 화면)에 쓰는 단계 정의입니다.
///
/// 화면 문구와 연출을 한곳에 모아 두어, 안내 순서를 바꾸거나 문구를 고칠 때
/// 이 파일만 수정하면 되게 했습니다.
enum HowToPlayScene {
  /// 태블릿을 테이블 가운데에 눕혀 놓는 장면입니다.
  placeTablet,

  /// 휴대폰들이 참여 코드로 같은 방에 들어오는 장면입니다.
  joinRoom,

  /// 참여자들이 태블릿을 둘러싸고 자리에 앉는 장면입니다.
  takeSeats,

  /// 태블릿(공용 화면)과 휴대폰(개인 화면)을 함께 쓰며 플레이하는 장면입니다.
  play,
}

class HowToPlayStep {
  const HowToPlayStep({
    required this.scene,
    required this.badge,
    required this.title,
    required this.description,
    required this.tip,
  });

  final HowToPlayScene scene;

  /// 단계 번호 배지 문구입니다.
  final String badge;
  final String title;
  final String description;

  /// 한 줄로 짚어 주는 실제 플레이 요령입니다.
  final String tip;
}

List<HowToPlayStep> get howToPlaySteps => <HowToPlayStep>[
  HowToPlayStep(
    scene: HowToPlayScene.placeTablet,
    badge: '01',
    title: '태블릿을 테이블 가운데에'.localized,
    description: GameLocale.select(
      ko: '태블릿 한 대가 모두의 게임판이 됩니다.\n둘러앉은 사람 모두가 화면을 볼 수 있도록 테이블 가운데에 눕혀 놓으세요.',
      en: 'One tablet becomes the shared game board.\nLay it in the middle so everyone around the table can see it.',
      zhHans: '一台平板就是大家共享的游戏板。\n请将它平放在桌子中央，让所有人都能看见。',
      zhHant: '一台平板就是大家共享的遊戲板。\n請將它平放在桌子中央，讓所有人都能看見。',
    ),
    tip: '태블릿은 가로로 놓아 주세요.'.localized,
  ),
  HowToPlayStep(
    scene: HowToPlayScene.joinRoom,
    badge: '02',
    title: '휴대폰으로 참여 코드 입력'.localized,
    description: GameLocale.select(
      ko: '태블릿 화면에 뜬 참여 코드나 QR을 각자 휴대폰 앱에서 입력하면\n바로 같은 방에 들어옵니다.',
      en: 'Enter the join code or scan the QR shown on the tablet\nto join the same room from each phone.',
      zhHans: '在每部手机上输入平板显示的加入码或扫描二维码，\n即可进入同一房间。',
      zhHant: '在每部手機上輸入平板顯示的加入碼或掃描 QR Code，\n即可進入同一房間。',
    ),
    tip: '휴대폰은 각자 손에 들고 있어요.'.localized,
  ),
  HowToPlayStep(
    scene: HowToPlayScene.takeSeats,
    badge: '03',
    title: '태블릿을 둘러싸고 앉기'.localized,
    description: GameLocale.select(
      ko: '참여한 사람은 태블릿을 중심으로 둥글게 앉습니다.\n앉은 순서 그대로 자리 배치 화면에서 자리를 맞춰 주세요.',
      en: 'Sit around the tablet, then match the on-screen seats\nto the order everyone is sitting in.',
      zhHans: '大家围坐在平板周围，\n再按实际顺序调整屏幕上的座位。',
      zhHant: '大家圍坐在平板周圍，\n再按實際順序調整畫面上的座位。',
    ),
    tip: '자리는 화면에서 끌어 바꿀 수 있어요.'.localized,
  ),
  HowToPlayStep(
    scene: HowToPlayScene.play,
    badge: '04',
    title: '함께 보는 화면 + 나만 보는 화면'.localized,
    description: GameLocale.select(
      ko: '태블릿은 모두가 함께 보는 게임판, 휴대폰은 나만 보는 카드와 선택지입니다.\n내 차례가 오면 휴대폰이 알려 줍니다.',
      en: 'The tablet is the shared board; your phone shows private cards and choices.\nYour phone lets you know when it is your turn.',
      zhHans: '平板是大家共享的游戏板，手机显示只有自己可见的卡牌和选项。\n轮到你时手机会提醒。',
      zhHant: '平板是大家共享的遊戲板，手機顯示只有自己可見的卡牌和選項。\n輪到你時手機會提醒。',
    ),
    tip: '휴대폰 화면은 옆 사람에게 보이지 않게!'.localized,
  ),
];
