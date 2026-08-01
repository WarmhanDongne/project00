import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/platform/dto/dto_firestore_value.dart';

class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.enabled,
    required this.genres,
    required this.minPlayers,
    required this.maxPlayers,
    required this.playTime,
    required this.order,
    required this.ruleVideoUrl,
    required this.isOwned,
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
      imageUrl: firestoreString(json['imageUrl']),
      enabled: json['enabled'] as bool? ?? true,
      genres: firestoreStringList(json['genres']),
      minPlayers: firestoreInt(json['minPlayers']),
      maxPlayers: firestoreInt(json['maxPlayers']),
      playTime: firestoreInt(json['playTime']),
      order: firestoreInt(json['order']),
      ruleVideoUrl: firestoreString(json['ruleVideoUrl']),
      isOwned: json['isOwned'] == true,
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final bool enabled;
  final List<String> genres;
  final int minPlayers;
  final int maxPlayers;
  final int playTime;
  final int order;
  final String ruleVideoUrl;
  final bool isOwned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genresText => genres.join(', ');
}
