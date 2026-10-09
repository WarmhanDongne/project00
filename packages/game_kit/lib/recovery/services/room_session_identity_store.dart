import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';

String newRecoveryOperationId(String prefix) {
  final random = Random.secure();
  return '${prefix}_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

/// One serialized value keeps identity and pending transport allocations atomic.
class RoomSessionIdentityStore extends ChangeNotifier {
  RoomSessionIdentityStore({
    this.storageKey = 'mosigame_room_identity_v1',
    this.persist,
  });
  static final instance = RoomSessionIdentityStore();
  final String storageKey;
  final Future<bool> Function(String key, String value)? persist;
  Map<String, dynamic>? _records;
  Future<void> _writes = Future.value();
  Future<void>? _loading;

  String _key(String uid, String role, String code) =>
      '$uid/$role/${code.trim().toUpperCase()}';

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    if (_records != null) return;
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    _records = encoded == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  }

  RoomSessionIdentity? current(String uid, String role, String roomCode) {
    final record = _records?[_key(uid, role, roomCode)];
    if (record is! Map || record['identity'] is! Map) return null;
    return RoomSessionIdentity.fromJson(
      Map<String, dynamic>.from(record['identity'] as Map),
    );
  }

  RoomSessionIdentity? latestFor(String uid, String role) {
    for (final record in (_records ?? {}).values.toList().reversed) {
      final value = record is Map ? record['identity'] : null;
      if (value is Map && value['uid'] == uid && value['role'] == role) {
        return RoomSessionIdentity.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return null;
  }

  Map<String, dynamic>? pending(String uid, String role, String roomCode) {
    final record = _records?[_key(uid, role, roomCode)];
    final value = record is Map ? record['pending'] : null;
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> save(
    RoomSessionIdentity identity, {
    String? completedOperationId,
  }) => _change(() {
    final previous = current(identity.uid, identity.role, identity.roomCode);
    if (previous?.roomInstanceId == identity.roomInstanceId &&
        previous!.connectionSeq > identity.connectionSeq) {
      return;
    }
    final pendingValue = pending(
      identity.uid,
      identity.role,
      identity.roomCode,
    );
    _records![_key(identity.uid, identity.role, identity.roomCode)] = {
      'identity': identity.toJson(),
      if (pendingValue != null &&
          pendingValue['operationId'] != completedOperationId)
        'pending': pendingValue,
    };
  });

  Future<void> savePending(
    String uid,
    String role,
    String roomCode,
    Map<String, dynamic> payload,
  ) => _change(() {
    final key = _key(uid, role, roomCode);
    final existing = _records![key];
    _records![key] = {
      ...(existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{}),
      'pending': payload,
    };
  });

  Future<void> clear(
    String uid,
    String role,
    String roomCode, {
    String? onlyRoomInstanceId,
  }) => _change(() {
    final key = _key(uid, role, roomCode);
    if (onlyRoomInstanceId != null &&
        current(uid, role, roomCode)?.roomInstanceId != onlyRoomInstanceId) {
      return;
    }
    _records!.remove(key);
  });

  Future<void> _change(void Function() update) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      await load();
      final before = jsonEncode(_records);
      update();
      try {
        final preferences = await SharedPreferences.getInstance();
        if (!await (persist ?? preferences.setString)(
          storageKey,
          jsonEncode(_records),
        )) {
          throw StateError('Session identity save failed');
        }
        notifyListeners();
      } catch (_) {
        _records = Map<String, dynamic>.from(jsonDecode(before) as Map);
        rethrow;
      }
    });
    _writes = next;
    return next;
  }
}
