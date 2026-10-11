import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';

void main() {
  test(
    'catalog and ownership start together; catalog is shared only in flight',
    () async {
      final db = _Database();
      final auth = _Auth();
      final service = GameService(
        firestore: db,
        auth: auth,
        functions: _Functions(),
      );
      final first = service.fetchGames();
      final second = service.fetchGames();
      expect(db.reads, ['games', 'users/user', 'users/user']);
      db.catalog.complete(_Catalog());
      db.owner.complete(
        _Document('user', {
          'ownedGames': ['paid'],
        }),
      );
      expect((await first).map((g) => g.id), ['free', 'paid']);
      expect((await second).last.isOwned, isTrue);
      await service.fetchGames();
      expect(db.reads.where((v) => v == 'games').length, 2);
    },
  );

  test('an old account response is rejected', () async {
    final db = _Database();
    final auth = _Auth();
    final service = GameService(
      firestore: db,
      auth: auth,
      functions: _Functions(),
    );
    final result = expectLater(service.fetchGames(), throwsStateError);
    auth.currentUser = _User('other');
    db.catalog.complete(_Catalog());
    db.owner.complete(
      _Document('user', {
        'ownedGames': ['paid'],
      }),
    );
    await result;
  });

  test(
    'group entitlement and catalog overlap, stale group remains rejected',
    () async {
      final db = _Database();
      final functions = _Functions();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: functions,
      );
      final result = expectLater(
        service.fetchGroupGames(
          ['user'],
          roomCode: 'ABCDE',
          roomInstanceId: 'instance',
        ),
        throwsStateError,
      );
      expect(functions.calls, 1);
      expect(db.reads, ['games']);
      functions.reply.complete({'status': 'stale'});
      db.catalog.complete(_Catalog());
      await result;
    },
  );

  test('failed catalog read is released for retry', () async {
    final db = _Database();
    final service = GameService(
      firestore: db,
      auth: _Auth(),
      functions: _Functions(),
    );
    final result = expectLater(service.fetchGames(), throwsStateError);
    db.catalog.completeError(StateError('offline'));
    db.owner.complete(_Document('user', {}));
    await result;
    db.catalog = Completer()..complete(_Catalog());
    expect((await service.fetchGames()).map((g) => g.id), ['free']);
    expect(db.reads.where((v) => v == 'games').length, 2);
  });

  test('provider shares completion and allows a later refresh', () async {
    final service = _DeferredService();
    final provider = GameProvider(service: service);
    final first = provider.fetchGames();
    final second = provider.fetchGames();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 1);
    service.reply.complete([]);
    await Future.wait([first, second]);
    await provider.fetchGames();
    expect(service.calls, 2);
    provider.dispose();
  });

  test('disposed provider does not publish a pending response', () async {
    final service = _DeferredService();
    final provider = GameProvider(service: service);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final pending = provider.fetchGames();
    await Future<void>.delayed(Duration.zero);
    provider.dispose();
    service.reply.complete([]);
    await pending;
    expect(notifications, 1);
  });
}

class _DeferredService extends Fake implements GameService {
  final reply = Completer<List<GameInfo>>();
  var calls = 0;
  @override
  Future<List<GameInfo>> fetchGames() {
    calls++;
    return reply.future;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser = _User('user');
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Database extends Fake implements FirebaseFirestore {
  final reads = <String>[];
  Completer<QuerySnapshot<Map<String, dynamic>>> catalog = Completer();
  final owner = Completer<DocumentSnapshot<Map<String, dynamic>>>();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// Test-only SDK doubles hold reads pending to verify request overlap, not a
// production Firestore implementation. Unused calls still fail through Fake.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    db.reads.add(path);
    return db.catalog.future;
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(db, '${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    db.reads.add(path);
    return db.owner.future;
  }
}

class _Catalog extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    _Document('paid', {'accessType': 'paid', 'order': 2}),
    _Document('free', {'accessType': 'free', 'order': 1}),
  ];
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Functions extends Fake implements FirebaseFunctions {
  var calls = 0;
  final reply = Completer<Map<String, dynamic>>();
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(this);
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.functions);
  final _Functions functions;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    functions.calls++;
    return _Result(await functions.reply.future as T);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}
