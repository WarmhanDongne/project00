import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/firebase/utils/firestore_value.dart';

class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    this.rules = '',
    required this.imageUrl,
    required this.enabled,
    required this.genres,
    required this.minPlayers,
    required this.maxPlayers,
    required this.playTime,
    required this.order,
    required this.ruleVideoUrl,
    required this.isOwned,
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
      rules: firestoreString(json['rules']),
      imageUrl: firestoreString(json['imageUrl']),
      enabled: json['enabled'] as bool? ?? true,
      genres: firestoreStringList(json['genres']),
      minPlayers: firestoreInt(json['minPlayers']),
      maxPlayers: firestoreInt(json['maxPlayers']),
      playTime: firestoreInt(json['playTime']),
      order: firestoreInt(json['order']),
      ruleVideoUrl: firestoreString(json['ruleVideoUrl']),
      isOwned: json['isOwned'] == true,
      minAppVersion: firestoreString(json['minAppVersion']),
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String description;
  final String rules;
  final String imageUrl;
  final bool enabled;
  final List<String> genres;
  final int minPlayers;
  final int maxPlayers;
  final int playTime;
  final int order;
  final String ruleVideoUrl;
  final bool isOwned;

  /// 이 게임을 실행하는 데 필요한 최소 앱 버전입니다(Firestore `minAppVersion`).
  ///
  /// 새 게임을 서버에 등록할 때 그 게임이 포함된 앱 버전을 함께 적으면,
  /// 그 이전 빌드에서는 시작 대신 업데이트 안내가 표시됩니다. 빈 값이면
  /// 모든 버전에서 허용합니다.
  final String minAppVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genresText => genres.join(', ');
}
