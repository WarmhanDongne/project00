import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_kit/firebase/utils/firestore_value.dart';
import 'package:game_kit/models/game_room_context.dart';

enum GameAccessType {
  free,
  paid;

  static GameAccessType fromFirestore(Object? value) =>
      value == 'paid' ? GameAccessType.paid : GameAccessType.free;
}

/// 앱에 포함되어 누구나 플레이할 수 있는 게임입니다.
const bundledFreeGameIds = {'liars_poker', 'final_call', 'holdem'};

class GameInfo implements GameRoomMetadata {
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
    this.storeVisible = false,
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
      storeVisible: json['storeVisible'] == true,
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String id;
  @override
  final String name;
  final String description;
  final String tabletDescription;
  final String rules;
  @override
  final String imageUrl;

  /// 게임 **구성품 사진**입니다(모달의 미리보기 자리).
  ///
  /// Storage에 올린 그림의 내려받기 URL을 Firestore `componentImageUrl`에 적어
  /// 두면 앱 업데이트 없이 그림을 바꿀 수 있습니다. 비어 있거나 내려받기가
  /// 실패하면 플랫폼의 공통 준비 중 패널을 표시합니다.
  final String componentImageUrl;

  final bool enabled;
  final List<String> genres;
  final int minPlayers;
  final int maxPlayers;
  final int playTime;
  final int order;
  @override
  final String ruleVideoUrl;
  final bool isOwned;
  final GameAccessType accessType;

  bool get isFree =>
      bundledFreeGameIds.contains(id) || accessType == GameAccessType.free;
  bool get isAccessible => isFree || isOwned;

  /// 이 게임을 실행하는 데 필요한 최소 앱 버전입니다(Firestore `minAppVersion`).
  ///
  /// 새 게임을 서버에 등록할 때 그 게임이 포함된 앱 버전을 함께 적으면,
  /// 그 이전 빌드에서는 시작 대신 업데이트 안내가 표시됩니다. 빈 값이면
  /// 모든 버전에서 허용합니다.
  final String minAppVersion;

  /// 상점 매대에 진열할지입니다(Firestore `storeVisible`).
  ///
  /// `true`인 게임만 상점에 보입니다. 값이 없거나 `false`면 진열하지 않으며,
  /// 로비 선반·방 게임 목록에는 영향을 주지 않습니다.
  final bool storeVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genresText => genres.join(', ');

  String get effectiveTabletDescription {
    final tabletText = tabletDescription.trim();
    return tabletText.isEmpty ? description : tabletText;
  }
}
