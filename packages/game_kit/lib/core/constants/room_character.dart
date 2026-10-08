/// 방 캐릭터의 저장 ID와 화면 그림을 분리합니다.
/// 기존 서버·구버전 앱이 사용하는 동물 ID는 바꾸지 않고 새 그림만 연결합니다.
library;

class RoomCharacter {
  const RoomCharacter({required this.id, required this.label});

  /// 서버에 보내고 저장하는 ID입니다. 이미지 파일명으로 대체하지 않습니다.
  final String id;
  final String label;

  String get assetPath =>
      'packages/game_kit/assets/images/character/${_artById[id] ?? id}.webp';
}

// 기존 서버에서 허용하는 17개 ID를 그대로 사용합니다.
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
  RoomCharacter(id: 'rabbit', label: '티슈 상자'),
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
  // 대응하는 기존 서버 ID가 없는 세 그림은 읽기/장식 전용입니다.
  // 선택지로 추가하려면 서버의 ID 확장을 별도로 배포해야 합니다.
  'cone': const RoomCharacter(id: 'cone', label: '삼각콘'),
  'catcher': const RoomCharacter(id: 'catcher', label: '포수 마스크'),
  'bandage': const RoomCharacter(id: 'bandage', label: '붕대'),
});

RoomCharacter roomCharacterById(String? id) =>
    _roomCharactersById[id] ?? _roomCharactersById[defaultRoomCharacterId]!;

String roomCharacterAssetPath(String? id) => roomCharacterById(id).assetPath;
