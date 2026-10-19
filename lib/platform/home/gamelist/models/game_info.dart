import 'dart:ui' show Locale;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_kit/firebase/utils/firestore_value.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'game_catalog_id.dart';

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
    this.localizedNames = const {},
    required this.description,
    this.localizedDescriptions = const {},
    this.tabletDescription = '',
    this.rules = '',
    this.localizedRules = const {},
    required this.imageUrl,
    this.componentImageUrl = '',
    required this.enabled,
    required this.genres,
    this.localizedGenres = const {},
    required this.minPlayers,
    required this.maxPlayers,
    required this.playTime,
    required this.order,
    required this.ruleVideoUrl,
    required this.isOwned,
    this.accessType = GameAccessType.free,
    this.minAppVersion = '',
    this.storeVisible = false,
    this.storeProductIds = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory GameInfo.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool isOwned = false,
  }) {
    final data = snapshot.data();
    return GameInfo.fromJson({
      ...?data,
      'id': snapshot.id,
      'isOwned': isOwned,
      // Catalog documents must opt in explicitly. A missing or mistyped value
      // must not publish a newly registered game by accident.
      'enabled': data?['enabled'] == true,
    });
  }

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    final id = runtimeGameId(firestoreString(json['id']));
    return GameInfo(
      id: id,
      name: firestoreString(json['name'], fallback: '이름 없음'),
      localizedNames: _localizedStrings(json['localizedNames']),
      description: firestoreString(json['description']),
      localizedDescriptions: _localizedStrings(json['localizedDescriptions']),
      tabletDescription: firestoreString(json['tabletDescription']),
      rules: firestoreString(json['rules']),
      localizedRules: _localizedStrings(json['localizedRules']),
      imageUrl: firestoreString(json['imageUrl']),
      componentImageUrl: firestoreString(json['componentImageUrl']),
      enabled: json['enabled'] as bool? ?? true,
      genres: firestoreStringList(json['genres']),
      localizedGenres: _localizedStringLists(json['localizedGenres']),
      // Classic Yut is a built-in four-seat game that supports two players.
      // Keep the visible range correct even if the remote catalog is stale.
      minPlayers: id == 'yut' ? 2 : firestoreInt(json['minPlayers']),
      maxPlayers: id == 'yut' ? 4 : firestoreInt(json['maxPlayers']),
      playTime: firestoreInt(json['playTime']),
      order: firestoreInt(json['order']),
      ruleVideoUrl: firestoreString(json['ruleVideoUrl']),
      isOwned: json['isOwned'] == true,
      accessType: GameAccessType.fromFirestore(json['accessType']),
      minAppVersion: firestoreString(json['minAppVersion']),
      storeVisible: json['storeVisible'] == true,
      storeProductIds: _storeProductIds(json['storeProductIds']),
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String id;
  @override
  final String name;
  final Map<String, String> localizedNames;
  final String description;
  final Map<String, String> localizedDescriptions;
  final String tabletDescription;
  final String rules;
  final Map<String, String> localizedRules;
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
  final Map<String, List<String>> localizedGenres;
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

  /// 앱스토어별 비소모성 상품 ID입니다.
  ///
  /// 현재 결제 게이트웨이는 비활성 상태라 이 값만으로 과금되지 않습니다. 실제
  /// 결제를 붙일 때 `appStore`와 `googlePlay` 키를 사용하고, 가격은 스토어에서
  /// 조회합니다.
  final Map<String, String> storeProductIds;

  String? storeProductId(String store) => storeProductIds[store];

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genresText => genres.join(', ');

  /// Firestore의 다국어 이름 중 현재 앱 언어에 맞는 값을 반환합니다.
  ///
  /// 기존 문서는 [name]만 가지고 있으므로 exact locale, language, English,
  /// legacy name 순으로 안전하게 대체합니다.
  String localizedName(Locale locale) {
    return _localizedValue(localizedNames, locale) ?? name;
  }

  String get englishName => localizedNames['en'] ?? name;

  String localizedDescription(Locale locale) {
    return _localizedValue(localizedDescriptions, locale) ?? description;
  }

  String localizedRulesFor(Locale locale) {
    return _localizedValue(localizedRules, locale) ?? rules;
  }

  List<String> localizedGenresFor(Locale locale) {
    return _localizedValue(localizedGenres, locale) ?? genres;
  }

  String localizedGenresText(Locale locale, {String separator = ', '}) {
    return localizedGenresFor(locale).join(separator);
  }

  String effectiveTabletDescriptionFor(Locale locale) {
    final localizedText = _localizedValue(localizedDescriptions, locale);
    if (localizedText != null) return localizedText;
    final tabletText = tabletDescription.trim();
    return tabletText.isEmpty ? description : tabletText;
  }

  /// Locale-aware callers should use [effectiveTabletDescriptionFor].
  String get effectiveTabletDescription {
    final tabletText = tabletDescription.trim();
    return tabletText.isEmpty ? description : tabletText;
  }
}

String _localeKey(Locale locale) => switch (locale.languageCode) {
  'zh' when locale.scriptCode == 'Hant' => 'zh-Hant',
  'zh' when locale.scriptCode == 'Hans' => 'zh-Hans',
  'zh' when const {'TW', 'HK', 'MO'}.contains(locale.countryCode) => 'zh-Hant',
  'zh' => 'zh-Hans',
  final language => language,
};

T? _localizedValue<T>(Map<String, T> values, Locale locale) {
  return values[_localeKey(locale)] ??
      values[locale.languageCode] ??
      values['en'];
}

Map<String, String> _localizedStrings(Object? value) {
  if (value is! Map) return const {};
  final strings = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().replaceAll('_', '-').trim();
    final text = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && text.isNotEmpty) strings[key] = text;
  }
  return Map.unmodifiable(strings);
}

Map<String, String> _storeProductIds(Object? value) {
  if (value is! Map) return const {};
  final ids = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final id = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && id.isNotEmpty) ids[key] = id;
  }
  return Map.unmodifiable(ids);
}

Map<String, List<String>> _localizedStringLists(Object? value) {
  if (value is! Map) return const {};
  final lists = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().replaceAll('_', '-').trim();
    final items = firestoreStringList(entry.value);
    if (key.isNotEmpty && items.isNotEmpty) {
      lists[key] = List.unmodifiable(items);
    }
  }
  return Map.unmodifiable(lists);
}
