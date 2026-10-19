import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// 상점에 노출하는 여러 게임 묶음입니다. 묶음 구매 시 소유권은 각 게임 ID로
/// 따로 기록하며, 이 모델은 읽기 전용 진열 카탈로그만 다룹니다.
class GameBundle {
  const GameBundle({
    required this.id,
    required this.name,
    this.localizedNames = const {},
    required this.description,
    this.localizedDescriptions = const {},
    required this.gameIds,
    required this.order,
    required this.storeVisible,
  });

  factory GameBundle.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return GameBundle(
      id: snapshot.id,
      name: _string(data['name']),
      localizedNames: _localized(data['localizedNames']),
      description: _string(data['description']),
      localizedDescriptions: _localized(data['localizedDescriptions']),
      gameIds: _strings(data['gameIds']),
      order: data['order'] is int ? data['order'] as int : 0,
      storeVisible: data['storeVisible'] == true,
    );
  }

  final String id;
  final String name;
  final Map<String, String> localizedNames;
  final String description;
  final Map<String, String> localizedDescriptions;
  final List<String> gameIds;
  final int order;
  final bool storeVisible;

  String localizedName(Locale locale) =>
      _localizedValue(localizedNames, locale) ?? name;

  String localizedDescription(Locale locale) =>
      _localizedValue(localizedDescriptions, locale) ?? description;

  static String _string(Object? value) => value is String ? value : '';

  static Map<String, String> _localized(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    });
  }

  static List<String> _strings(Object? value) =>
      value is List ? List.unmodifiable(value.whereType<String>()) : const [];

  static String? _localizedValue(Map<String, String> values, Locale locale) {
    final exact = [
      if (locale.scriptCode != null)
        '${locale.languageCode}-${locale.scriptCode}',
      if (locale.countryCode != null)
        '${locale.languageCode}-${locale.countryCode}',
      locale.languageCode,
      'en',
    ];
    for (final key in exact) {
      final value = values[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
