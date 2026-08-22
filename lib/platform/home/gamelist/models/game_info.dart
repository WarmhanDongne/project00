import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/firebase/utils/firestore_value.dart';

enum GameAccessType {
  free,
  paid;

  static GameAccessType fromFirestore(Object? value) =>
      value == 'paid' ? GameAccessType.paid : GameAccessType.free;
}

class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    this.tabletDescription = '',
    this.rules = '',
    required this.imageUrl,
    this.componentImageUrl = '',
    required this.enabled,
    required this.genres,
    required this.minPlayers,
    required this.maxPlayers,
    required this.playTime,
    required this.order,
    required this.ruleVideoUrl,
    required this.isOwned,
    this.accessType = GameAccessType.free,
    this.minAppVersion = '',
    this.createdAt,
    this.updatedAt,
  });

  factory GameInfo.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool isOwned = false,
  }) {
    return GameInfo.fromJson({
      ...?snapshot.data(),
      'id': snapshot.id,
      'isOwned': isOwned,
    });
  }

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    return GameInfo(
      id: firestoreString(json['id']),
      name: firestoreString(json['name'], fallback: '이름 없음'),
      description: firestoreString(json['description']),
      tabletDescription: firestoreString(json['tabletDescription']),
      rules: firestoreString(json['rules']),
      imageUrl: firestoreString(json['imageUrl']),
      componentImageUrl: firestoreString(json['componentImageUrl']),
      enabled: json['enabled'] as bool? ?? true,
      genres: firestoreStringList(json['genres']),
      minPlayers: firestoreInt(json['minPlayers']),
      maxPlayers: firestoreInt(json['maxPlayers']),
      playTime: firestoreInt(json['playTime']),
      order: firestoreInt(json['order']),
      ruleVideoUrl: firestoreString(json['ruleVideoUrl']),
      isOwned: json['isOwned'] == true,
      accessType: GameAccessType.fromFirestore(json['accessType']),
      minAppVersion: firestoreString(json['minAppVersion']),
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String description;
  final String tabletDescription;
  final String rules;
  final String imageUrl;

  /// 게임 **구성품 사진**입니다(모달의 미리보기 자리).
  ///
  /// Storage에 올린 그림의 내려받기 URL을 Firestore `componentImageUrl`에 적어
  /// 두면 앱 업데이트 없이 그림을 바꿀 수 있습니다. 비어 있거나 내려받기가
  /// 실패하면 게임이 코드로 그리는 미리보기(`buildTabletPreviewArtwork`)를
  /// 그대로 씁니다 — 오프라인에서도 모달이 비지 않습니다.
  final String componentImageUrl;

  final bool enabled;
  final List<String> genres;
  final int minPlayers;
  final int maxPlayers;
  final int playTime;
  final int order;
  final String ruleVideoUrl;
  final bool isOwned;
  final GameAccessType accessType;

  bool get isFree => accessType == GameAccessType.free;
  bool get isAccessible => isFree || isOwned;

  /// 이 게임을 실행하는 데 필요한 최소 앱 버전입니다(Firestore `minAppVersion`).
  ///
  /// 새 게임을 서버에 등록할 때 그 게임이 포함된 앱 버전을 함께 적으면,
  /// 그 이전 빌드에서는 시작 대신 업데이트 안내가 표시됩니다. 빈 값이면
  /// 모든 버전에서 허용합니다.
  final String minAppVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genresText => genres.join(', ');

  String get effectiveTabletDescription {
    final tabletText = tabletDescription.trim();
    return tabletText.isEmpty ? description : tabletText;
  }
}
