import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/games/mafia/dev/mafia_practice_fakes.dart';
import 'package:project00/games/mafia/services/mafia_command_service.dart';
import 'package:project00/games/mafia/services/mafia_query_service.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';

//=======================마피아 연습 원격 접속 (개발 전용)=====================
/// 같은 맥에서 열린 [MafiaPracticeServer]에 붙어, 실제 휴대폰 화면을 그대로
/// 돌리기 위한 [MafiaService] 대체품입니다. Firebase는 전혀 거치지 않습니다.
class MafiaPracticeRemoteClient {
  MafiaPracticeRemoteClient._(this._socket) {
    _socket.listen(
      _onMessage,
      onDone: () => connected.value = false,
      onError: (_) => connected.value = false,
    );
  }

  final WebSocket _socket;

  /// 서버가 배정한 내 자리입니다(폰1 = p1, 폰2 = p2).
  String uid = '';
  String nickname = '';

  /// 소켓이 살아 있는지입니다. 끊기면 접속 화면이 재접속을 안내합니다.
  final ValueNotifier<bool> connected = ValueNotifier(true);

  final Completer<void> _hello = Completer<void>();

  /// [close]가 불린 뒤 소켓에 남아 있던 메시지를 버리기 위한 표시입니다.
  bool _closed = false;
  Map<String, Object?>? _lastPublic;
  Object? _lastPrivate;
  final StreamController<Map<String, Object?>> _publicUpdates =
      StreamController.broadcast();
  final StreamController<Object?> _privateUpdates =
      StreamController.broadcast();

  static Future<MafiaPracticeRemoteClient> connect({
    String host = '127.0.0.1',
    int port = 8765,
  }) async {
    final socket = await WebSocket.connect('ws://$host:$port');
    final client = MafiaPracticeRemoteClient._(socket);
    // 자리 배정을 받아야 어느 플레이어의 화면인지 알 수 있습니다.
    await client._hello.future.timeout(const Duration(seconds: 5));
    return client;
  }

  void _onMessage(dynamic raw) {
    if (_closed) return;
    Map<String, Object?> message;
    try {
      message = (jsonDecode(raw as String) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'hello':
        uid = message['uid'] as String? ?? '';
        nickname = message['nickname'] as String? ?? uid;
        if (!_hello.isCompleted) _hello.complete();
      case 'public':
        final data = (message['data'] as Map?)?.cast<String, Object?>();
        if (data != null) {
          _lastPublic = data;
          _publicUpdates.add(data);
        }
      case 'private':
        _lastPrivate = message['data'];
        _privateUpdates.add(_lastPrivate);
    }
  }

  MafiaService get service => MafiaService(
    command: _RemoteCommands(this),
    query: _RemoteQuery(this),
    interruption: MafiaPracticeNoopInterruption(),
  );

  /// 새 구독자가 마지막 상태부터 바로 보게 하는 스트림입니다.
  Stream<DatabaseEvent> _watch<T>(
    StreamController<T> updates,
    T? Function() last,
  ) {
    late StreamController<DatabaseEvent> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<DatabaseEvent>(
      onListen: () {
        final cached = last();
        if (cached != null) controller.add(MafiaPracticeFakeEvent(cached));
        subscription = updates.stream.listen(
          (value) => controller.add(MafiaPracticeFakeEvent(value)),
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void _sendCommand(String name, {String? targetUid}) {
    _socket.add(
      jsonEncode({'type': 'command', 'name': name, 'targetUid': ?targetUid}),
    );
  }

  void close() {
    _closed = true;
    connected.value = false;
    _socket.close();
    _publicUpdates.close();
    _privateUpdates.close();
  }
}

class _RemoteQuery implements MafiaQueryService {
  _RemoteQuery(this.client);
  final MafiaPracticeRemoteClient client;

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) =>
      client._watch(client._publicUpdates, () => client._lastPublic);

  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => client._watch(client._privateUpdates, () => client._lastPrivate);

  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async =>
      MafiaPracticeFakeSnapshot(client._lastPublic);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 휴대폰이 쓰는 조작 명령만 서버로 보냅니다. 성공 응답은 형식만 맞추고,
/// 실제 화면 갱신은 상태 스트림이 담당합니다(실서버와 같은 원리).
class _RemoteCommands implements MafiaCommandService {
  _RemoteCommands(this.client);
  final MafiaPracticeRemoteClient client;

  @override
  Future<Map<String, dynamic>> confirmRole({required String roomCode}) async {
    client._sendCommand('confirmRole');
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> submitNightAction({
    required String roomCode,
    required String targetUid,
  }) async {
    client._sendCommand('submitNightAction', targetUid: targetUid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> endDiscussion({required String roomCode}) async {
    client._sendCommand('endDiscussion');
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> submitVote({
    required String roomCode,
    required String targetUid,
  }) async {
    client._sendCommand('submitVote', targetUid: targetUid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> warmUp({required String roomCode}) async =>
      const {'success': true};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
