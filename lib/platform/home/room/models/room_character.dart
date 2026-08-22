class RoomCharacter {
  const RoomCharacter({required this.id, required this.label});

  final String id;
  final String label;

  String get assetPath => 'assets/images/character/$id.webp';
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

bool isRoomCharacterId(String id) =>
    roomCharacters.any((character) => character.id == id);

String roomCharacterAssetPath(String? id) => roomCharacterById(id).assetPath;
