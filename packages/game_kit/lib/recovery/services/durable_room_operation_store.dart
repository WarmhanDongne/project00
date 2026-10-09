import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

/// Intent and immutable request are one durable value. Unknown results never expire.
class DurableRoomOperationStore {
  DurableRoomOperationStore({
    this.storageKey = 'mosigame_room_operations_v1',
    this.persist,
  });
  static final instance = DurableRoomOperationStore();
  final String storageKey;
  final Future<bool> Function(String key, String value)? persist;
  Map<String, dynamic>? _records;
  Future<void>? _loadFuture;
  Future<void> _writes = Future.value();
  Future<void> load() => _loadFuture ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(storageKey);
    _records = encoded == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  }

  List<Map<String, dynamic>> pendingFor(String uid) => [
    for (final value in (_records ?? {}).values)
      if (value is Map && value['uid'] == uid && value['state'] != 'confirmed')
        _copy(value),
  ];
  List<Map<String, dynamic>> recordsFor(String uid) => [
    for (final value in (_records ?? {}).values.toList().reversed)
      if (value is Map && value['uid'] == uid) _copy(value),
  ];
  Future<Map<String, dynamic>> begin({
    required String uid,
    required String kind,
    required String scope,
    required Map<String, dynamic> payload,
  }) async {
    late Map<String, dynamic> result;
    await _change(() {
      final key = '$uid/$kind/$scope';
      final previous = _records![key];
      if (previous is Map && previous['state'] != 'confirmed') {
        result = _copy(previous);
      } else {
        result = {
          'key': key,
          'uid': uid,
          'kind': kind,
          'scope': scope,
          'state': 'requested',
          'requestedAt': DateTime.now().millisecondsSinceEpoch,
          'payload': {
            ...payload,
            'operationId':
                payload['operationId'] ?? newRecoveryOperationId(kind),
          },
        };
        _records![key] = _copy(result);
      }
    });
    return _copy(result);
  }

  Map<String, dynamic> _copy(Map value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  Future<void> mark(Map<String, dynamic> record, String state) => _change(() {
    final current = _records![record['key']];
    if (current is Map &&
        (current['payload'] as Map)['operationId'] ==
            (record['payload'] as Map)['operationId']) {
      _records![record['key']] = {...current, 'state': state};
    }
  });
  Future<void> _change(void Function() action) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      await load();
      final before = jsonEncode(_records);
      action();
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await (persist ?? prefs.setString)(
          storageKey,
          jsonEncode(_records),
        )) {
          throw StateError('Intent save failed');
        }
      } catch (_) {
        _records = Map<String, dynamic>.from(jsonDecode(before) as Map);
        rethrow;
      }
    });
    _writes = next;
    return next;
  }
}
