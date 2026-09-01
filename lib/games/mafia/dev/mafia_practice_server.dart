// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:project00/games/mafia/dev/mafia_practice_engine.dart';

// //=======================마피아 연습 서버 (개발 전용)==========================
// /// 연습 엔진을 같은 맥의 다른 시뮬레이터에 열어 주는 WebSocket 서버입니다.
// ///
// /// 목적: 방을 파지 않고 **태블릿 시뮬레이터 1대(호스트) + 폰 시뮬레이터
// /// 여러 대**로 실제 흐름을 함께 보는 것. iOS 시뮬레이터는 맥의 네트워크를
// /// 그대로 쓰므로 폰들이 `127.0.0.1`로 접속하면 됩니다. Firebase는 전혀
// /// 거치지 않습니다.
// ///
// /// 규약(JSON 한 줄씩):
// /// - 서버→폰: `{"type":"hello","uid":"p1","nickname":"폰1"}` 접속 직후 1회,
// ///   이후 상태가 바뀔 때마다 `{"type":"public","data":{...}}`와
// ///   `{"type":"private","data":{...}}`
// /// - 폰→서버: `{"type":"command","name":"confirmRole",...}` — 엔진의 사람
// ///   조작 4가지(confirmRole·submitNightAction·endDiscussion·submitVote)만.
// class MafiaPracticeServer {
//   HttpServer? _http;
//   MafiaPracticeEngine? _engine;
//   final List<_PracticeClient> _clients = [];

//   /// 접속한 폰들의 별명 목록입니다. 조종판 상태 표시가 구독합니다.
//   final ValueNotifier<List<String>> connectedNames = ValueNotifier(const []);

//   bool get isRunning => _http != null;
//   int? get port => _http?.port;

//   /// 서버를 켜고(이미 켜져 있으면 유지) [engine]에 묶습니다.
//   ///
//   /// '새 판'으로 엔진이 바뀌어도 폰의 소켓은 끊지 않고 새 엔진에 다시
//   /// 구독시킵니다. 폰에서 다시 접속할 필요가 없습니다.
//   Future<void> start(MafiaPracticeEngine engine, {int port = 8765}) async {
//     _engine = engine;
//     if (_http == null) {
//       // 같은 맥 안에서만 쓰는 개발 도구라 loopback에만 엽니다.
//       _http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
//       _http!.listen(_handleRequest);
//     }
//     for (final client in List.of(_clients)) {
//       client.bind(engine, _assignUid(exclude: client));
//     }
//     _notify();
//   }

//   Future<void> stop() async {
//     for (final client in List.of(_clients)) {
//       client.close();
//     }
//     _clients.clear();
//     await _http?.close(force: true);
//     _http = null;
//     _notify();
//   }

//   Future<void> _handleRequest(HttpRequest request) async {
//     if (!WebSocketTransformer.isUpgradeRequest(request)) {
//       request.response
//         ..statusCode = HttpStatus.badRequest
//         ..close();
//       return;
//     }
//     final socket = await WebSocketTransformer.upgrade(request);
//     final engine = _engine;
//     if (engine == null) {
//       socket.close();
//       return;
//     }
//     final client = _PracticeClient(socket, onClosed: _remove);
//     _clients.add(client);
//     client.bind(engine, _assignUid(exclude: client));
//     _notify();
//   }

//   /// 접속 순서대로 비어 있는 사람 자리를 줍니다. 자리가 다 찼으면 첫 자리를
//   /// 함께 봅니다(관전 겸 재접속 대비 — 개발 도구라 이 정도로 충분합니다).
//   String _assignUid({required _PracticeClient exclude}) {
//     final engine = _engine!;
//     final taken = _clients
//         .where((client) => client != exclude)
//         .map((client) => client.uid)
//         .toSet();
//     return engine.humanUids.firstWhere(
//       (uid) => !taken.contains(uid),
//       orElse: () => engine.humanUids.first,
//     );
//   }

//   void _remove(_PracticeClient client) {
//     _clients.remove(client);
//     _notify();
//   }

//   void _notify() {
//     connectedNames.value = [
//       for (final client in _clients)
//         if (client.nickname != null) client.nickname!,
//     ];
//   }
// }

// /// 폰 한 대의 접속입니다. 엔진 스트림을 소켓으로 중계합니다.
// class _PracticeClient {
//   _PracticeClient(this._socket, {required this.onClosed}) {
//     _socket.listen(_onMessage, onDone: _handleDone, onError: (_) => close());
//   }

//   final WebSocket _socket;
//   final void Function(_PracticeClient) onClosed;
//   MafiaPracticeEngine? _engine;
//   String uid = '';
//   String? nickname;
//   StreamSubscription<Object?>? _publicSub;
//   StreamSubscription<Object?>? _privateSub;

//   /// 새 엔진(새 판)에 구독을 옮겨 붙입니다.
//   void bind(MafiaPracticeEngine engine, String assignedUid) {
//     _publicSub?.cancel();
//     _privateSub?.cancel();
//     _engine = engine;
//     uid = assignedUid;
//     nickname = engine.nicknameOf(assignedUid) ?? assignedUid;
//     _send({'type': 'hello', 'uid': uid, 'nickname': nickname});
//     _publicSub = engine.watchPublic().listen(
//       (event) => _send({'type': 'public', 'data': event.snapshot.value}),
//     );
//     _privateSub = engine
//         .watchPrivate(uid)
//         .listen(
//           (event) => _send({'type': 'private', 'data': event.snapshot.value}),
//         );
//     // 접속 직후 현재 상태를 바로 보게 한 번 흘립니다.
//     engine.publishNow();
//   }

//   void _onMessage(dynamic raw) {
//     final engine = _engine;
//     if (engine == null) return;
//     Map<String, Object?> message;
//     try {
//       message = (jsonDecode(raw as String) as Map).cast<String, Object?>();
//     } catch (_) {
//       return;
//     }
//     if (message['type'] != 'command') return;
//     final targetUid = message['targetUid'] as String? ?? '';
//     // 폰이 보낼 수 있는 명령만 받습니다. 단계 진행은 호스트(태블릿) 몫입니다.
//     switch (message['name']) {
//       case 'confirmRole':
//         engine.confirmRole(uid);
//       case 'submitNightAction':
//         engine.submitNightAction(uid, targetUid);
//       case 'endDiscussion':
//         engine.endDiscussion(uid);
//       case 'submitVote':
//         engine.submitVote(uid, targetUid);
//     }
//   }

//   void _send(Map<String, Object?> message) {
//     try {
//       _socket.add(jsonEncode(message));
//     } catch (_) {
//       // 닫히는 중이면 onDone이 정리합니다.
//     }
//   }

//   void _handleDone() {
//     _publicSub?.cancel();
//     _privateSub?.cancel();
//     onClosed(this);
//   }

//   void close() {
//     _publicSub?.cancel();
//     _privateSub?.cancel();
//     _socket.close();
//     onClosed(this);
//   }
// }
