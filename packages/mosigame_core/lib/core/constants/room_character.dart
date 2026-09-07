/// 방 참가자가 고르는 동물 캐릭터 목록입니다.
///
/// 방에서 고르지만 **게임 화면이 더 많이 씁니다** — 좌석, 관전 목록, 결과 화면,
/// 중단 안내가 전부 이 카탈로그로 얼굴을 그립니다. 그래서 플랫폼이 아니라
/// `core`에 둡니다. 게임 코드가 플랫폼을 import하지 않아야 게임을 별도 패키지로
/// 나눌 수 있습니다(`docs/engineering/PACKAGE_MIGRATION.md`).
///
/// 이 id 목록은 `database.rules.json`의 `characterId` 정규식과 같아야 합니다.
/// 캐릭터를 추가하면 규칙도 함께 고치고 배포하세요.

library;

//=======================방 참가자 캐릭터 카탈로그==============================

class RoomCharacter {
  const RoomCharacter({required this.id, required this.label});

  final String id;
  final String label;

  String get assetPath =>
      'packages/mosigame_core/assets/images/character/$id.webp';
}

const roomCharacters = <RoomCharacter>[
  RoomCharacter(id: 'bear', label: '곰'),
  RoomCharacter(id: 'bee', label: '벌'),
  RoomCharacter(id: 'cat', label: '고양이'),
  RoomCharacter(id: 'crab', label: '게'),
  RoomCharacter(id: 'deer', label: '사슴'),
  RoomCharacter(id: 'elephant', label: '코끼리'),
  RoomCharacter(id: 'frog', label: '개구리'),
  RoomCharacter(id: 'giraffe', label: '기린'),
  RoomCharacter(id: 'hedgehog', label: '고슴도치'),
  RoomCharacter(id: 'kindbear', label: '순한 곰'),
  RoomCharacter(id: 'octopus', label: '문어'),
  RoomCharacter(id: 'owl', label: '부엉이'),
  RoomCharacter(id: 'penguin', label: '펭귄'),
  RoomCharacter(id: 'rabbit', label: '토끼'),
  RoomCharacter(id: 'shark', label: '상어'),
  RoomCharacter(id: 'snake', label: '뱀'),
  RoomCharacter(id: 'whale', label: '고래'),
];

const defaultRoomCharacterId = 'frog';

RoomCharacter roomCharacterById(String? id) {
  for (final character in roomCharacters) {
    if (character.id == id) return character;
  }
  return roomCharacters.firstWhere(
    (character) => character.id == defaultRoomCharacterId,
  );
}

String roomCharacterAssetPath(String? id) => roomCharacterById(id).assetPath;
