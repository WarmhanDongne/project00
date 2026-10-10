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

  /// Starts survive service recreation and process restart until their result is known.
  Map<String, dynamic>? pendingGameStart(
    String uid,
    String role,
    String roomCode,
  ) {
    final record = _records?[_key(uid, role, roomCode)];
    final value = record is Map ? record['pendingGameStart'] : null;
    final identity = current(uid, role, roomCode);
    if (value is! Map ||
        identity == null ||
        value['payload'] is! Map ||
        value['payload']['roomInstanceId'] != identity.roomInstanceId ||
        value['payload']['membershipId'] != identity.membershipId) {
      return null;
    }
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  }

  /// Serial reservation prevents concurrent new services from allocating two IDs.
  Future<Map<String, dynamic>> retainGameStart(
    RoomSessionIdentity identity,
    String functionName,
    Map<String, dynamic> input,
    Map<String, dynamic> payload,
  ) async {
    if (payload['roomInstanceId'] != identity.roomInstanceId ||
        payload['membershipId'] != identity.membershipId ||
        payload['commandId'] is! String) {
      throw StateError('이전 참가 세션의 요청입니다.');
    }
    late Map<String, dynamic> retained;
    await _change(() {
      final currentIdentity = current(
        identity.uid,
        identity.role,
        identity.roomCode,
      );
      if (currentIdentity?.roomInstanceId != identity.roomInstanceId ||
          currentIdentity?.membershipId != identity.membershipId) {
        throw StateError('방 연결이 변경되었습니다.');
      }
      final existing = pendingGameStart(
        identity.uid,
        identity.role,
        identity.roomCode,
      );
      if (existing != null) {
        if (existing['functionName'] != functionName ||
            jsonEncode(_stableValue(existing['input'])) !=
                jsonEncode(_stableValue(input))) {
          throw StateError('이전 게임 시작 요청의 결과를 먼저 확인해주세요.');
        }
        retained = existing;
        return;
      }
      retained = Map<String, dynamic>.from(
        jsonDecode(
              jsonEncode({
                'functionName': functionName,
                'input': input,
                'payload': payload,
              }),
            )
            as Map,
      );
      final key = _key(identity.uid, identity.role, identity.roomCode);
      (_records![key] as Map)['pendingGameStart'] = retained;
    });
    return Map<String, dynamic>.from(retained['payload'] as Map);
  }

  Future<void> completeGameStart(
    RoomSessionIdentity identity,
    String commandId,
  ) => _change(() {
    final pending = pendingGameStart(
      identity.uid,
      identity.role,
      identity.roomCode,
    );
    if (pending?['payload']['roomInstanceId'] != identity.roomInstanceId ||
        pending?['payload']['commandId'] != commandId) {
      return;
    }
    (_records![_key(identity.uid, identity.role, identity.roomCode)] as Map)
        .remove('pendingGameStart');
  });

  Future<void> save(
    RoomSessionIdentity identity, {
    String? completedOperationId,
    bool Function()? isCurrent,
  }) => _change(() {
    if (isCurrent != null && !isCurrent()) throw StateError('이전 방 복구 요청입니다.');
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
    final pendingStart = pendingGameStart(
      identity.uid,
      identity.role,
      identity.roomCode,
    );
    _records![_key(identity.uid, identity.role, identity.roomCode)] = {
      'identity': identity.toJson(),
      if (pendingValue != null &&
          pendingValue['operationId'] != completedOperationId)
        'pending': pendingValue,
      if (previous?.roomInstanceId == identity.roomInstanceId &&
          previous?.membershipId == identity.membershipId &&
          pendingStart != null)
        'pendingGameStart': pendingStart,
    };
  });

  Future<void> savePending(
    String uid,
    String role,
    String roomCode,
    Map<String, dynamic> payload, {
    bool Function()? isCurrent,
  }) => _change(() {
    if (isCurrent != null && !isCurrent()) throw StateError('이전 방 복구 요청입니다.');
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
      final preferences = await SharedPreferences.getInstance();
      try {
        if (!await (persist ?? preferences.setString)(
          storageKey,
          jsonEncode(_records),
        )) {
          throw StateError('Session identity save failed');
        }
        notifyListeners();
      } catch (_) {
        _records = Map<String, dynamic>.from(jsonDecode(before) as Map);
        // setString changes its memory cache before the platform write returns.
        // A failed native write must not leave an unsent intent in that cache.
        if (persist == null) {
          try {
            await preferences.reload();
          } catch (_) {
            // Preserve the original write error and the restored live records.
          }
        }
        rethrow;
      }
    });
    _writes = next;
    return next;
  }
}

Object? _stableValue(Object? value) {
  if (value is List) return value.map(_stableValue).toList();
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _stableValue(value[key])};
  }
  return value;
}
