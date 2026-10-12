/// 방 캐릭터의 저장 ID와 화면 그림을 분리합니다.
/// 기존 서버·구버전 앱이 사용하는 동물 ID는 바꾸지 않고 새 그림만 연결합니다.
library;

import 'package:game_kit/localization/game_locale.dart';

class RoomCharacter {
  const RoomCharacter({required this.id, required this.label});

  /// 서버에 보내고 저장하는 ID입니다. 이미지 파일명으로 대체하지 않습니다.
  final String id;
  final String label;

  String get localizedLabel {
    final values = _localizedCharacterLabels[id];
    if (values == null || GameLocale.isKorean) return label;
    return GameLocale.isEnglish
        ? values.$1
        : GameLocale.isTraditionalChinese
        ? values.$3
        : values.$2;
  }

  String get assetPath =>
      'packages/game_kit/assets/images/character/${_artById[id] ?? id}.webp';
}

// 기존 서버에서 허용하는 ID 중 16개를 고를 수 있게 둡니다.
// 티슈 상자(`rabbit`)는 선택지에서 뺐고, 이미 저장된 값은 아래에서 계속 그립니다.
const roomCharacters = <RoomCharacter>[
  RoomCharacter(id: 'frog', label: '버거 포장지'),
  RoomCharacter(id: 'cat', label: '팝콘통'),
  RoomCharacter(id: 'bear', label: '양동이'),
  RoomCharacter(id: 'bee', label: '냄비'),
  RoomCharacter(id: 'kindbear', label: '택배 상자'),
  RoomCharacter(id: 'whale', label: '수박 헬멧'),
  RoomCharacter(id: 'crab', label: '모자와 마스크'),
  RoomCharacter(id: 'hedgehog', label: '꽉 조인 후드'),
  RoomCharacter(id: 'deer', label: '목도리'),
  RoomCharacter(id: 'elephant', label: '우주 헬멧'),
  RoomCharacter(id: 'shark', label: '용접 마스크'),
  RoomCharacter(id: 'owl', label: '물안경'),
  RoomCharacter(id: 'snake', label: '변장 안경'),
  RoomCharacter(id: 'penguin', label: '우유팩'),
  RoomCharacter(id: 'octopus', label: '컵라면'),
  RoomCharacter(id: 'giraffe', label: '전등갓'),
];

const defaultRoomCharacterId = 'frog';

const _artById = <String, String>{
  'bear': 'bucket',
  'bee': 'pot',
  'cat': 'popcorn',
  'crab': 'capmask',
  'deer': 'scarf',
  'elephant': 'astronaut',
  'frog': 'burger',
  'giraffe': 'lampshade',
  'hedgehog': 'hood',
  'kindbear': 'parcel',
  'octopus': 'cupnoodle',
  'owl': 'goggles',
  'penguin': 'milk',
  'rabbit': 'tissue',
  'shark': 'welder',
  'snake': 'disguise',
  'whale': 'watermelon',
};

final Map<String, RoomCharacter> _roomCharactersById = Map.unmodifiable({
  for (final character in roomCharacters) character.id: character,
  // 리디자인 개발 빌드가 이미 저장한 이미지 ID도 읽고, 같은 얼굴의 중복을 막습니다.
  for (final character in roomCharacters) _artById[character.id]!: character,
  // 선택지에서 뺀 티슈 상자도 예전 방·기기에 남은 값은 같은 그림으로 읽습니다.
  'rabbit': const RoomCharacter(id: 'rabbit', label: '티슈 상자'),
  'tissue': const RoomCharacter(id: 'rabbit', label: '티슈 상자'),
  // 대응하는 기존 서버 ID가 없는 세 그림은 읽기/장식 전용입니다.
  // 선택지로 추가하려면 서버의 ID 확장을 별도로 배포해야 합니다.
  'cone': const RoomCharacter(id: 'cone', label: '삼각콘'),
  'catcher': const RoomCharacter(id: 'catcher', label: '포수 마스크'),
  'bandage': const RoomCharacter(id: 'bandage', label: '붕대'),
});

RoomCharacter roomCharacterById(String? id) =>
    _roomCharactersById[id] ?? _roomCharactersById[defaultRoomCharacterId]!;

String roomCharacterAssetPath(String? id) => roomCharacterById(id).assetPath;

const _localizedCharacterLabels = <String, (String, String, String)>{
  'frog': ('Burger wrapper', '汉堡包装纸', '漢堡包裝紙'),
  'cat': ('Popcorn tub', '爆米花桶', '爆米花桶'),
  'bear': ('Bucket', '水桶', '水桶'),
  'bee': ('Pot', '锅', '鍋子'),
  'kindbear': ('Parcel box', '快递箱', '包裹箱'),
  'whale': ('Watermelon helmet', '西瓜头盔', '西瓜頭盔'),
  'crab': ('Cap and mask', '帽子和口罩', '帽子和口罩'),
  'hedgehog': ('Tight hood', '紧身兜帽', '緊身兜帽'),
  'deer': ('Scarf', '围巾', '圍巾'),
  'elephant': ('Space helmet', '太空头盔', '太空頭盔'),
  'shark': ('Welding mask', '焊接面罩', '焊接面罩'),
  'owl': ('Goggles', '护目镜', '護目鏡'),
  'snake': ('Disguise glasses', '伪装眼镜', '偽裝眼鏡'),
  'penguin': ('Milk carton', '牛奶盒', '牛奶盒'),
  'octopus': ('Cup noodles', '杯面', '杯麵'),
  'giraffe': ('Lampshade', '灯罩', '燈罩'),
  'rabbit': ('Tissue box', '纸巾盒', '衛生紙盒'),
  'cone': ('Traffic cone', '路锥', '三角錐'),
  'catcher': ('Catcher mask', '捕手面罩', '捕手面罩'),
  'bandage': ('Bandage', '绷带', '繃帶'),
};
