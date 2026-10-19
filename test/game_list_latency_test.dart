import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/store/services/game_purchase_gateway.dart';

void main() {
  test('catalog text follows locale with legacy fallback', () {
    final game = GameInfo.fromJson({
      'id': 'liars',
      'name': 'legacy',
      'localizedNames': {
        'ko': '라이어스',
        'en': 'Liars',
        'zh_Hans': '骗子',
        'zh-Hant': '騙子',
      },
      'description': '기존 소개',
      'localizedDescriptions': {
        'ko': '한국어 소개',
        'en': 'English description',
        'zh_Hans': '简体介绍',
        'zh-Hant': '繁體介紹',
      },
      'rules': '기존 규칙',
      'localizedRules': {
        'ko': '한국어 규칙',
        'en': 'English rules',
        'zh-Hans': '简体规则',
        'zh-Hant': '繁體規則',
      },
      'genres': ['기존 장르'],
      'localizedGenres': {
        'ko': ['카드', '블러핑'],
        'en': ['Cards', 'Bluffing'],
        'zh-Hans': ['卡牌', '诈唬'],
        'zh-Hant': ['卡牌', '詐唬'],
      },
    });

    expect(game.id, 'liars_poker');
    expect(game.localizedName(const Locale('ko')), '라이어스');
    expect(game.localizedName(const Locale('en')), 'Liars');
    expect(
      game.localizedName(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
      '骗子',
    );
    expect(
      game.localizedName(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      '騙子',
    );
    expect(game.localizedName(const Locale('ja')), 'Liars');
    expect(game.englishName, 'Liars');
    expect(
      game.localizedDescription(const Locale('en')),
      'English description',
    );
    expect(
      game.localizedDescription(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      '繁體介紹',
    );
    expect(game.localizedRulesFor(const Locale('ja')), 'English rules');
    expect(
      game.localizedGenresFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
      ['卡牌', '诈唬'],
    );
    expect(
      game.localizedGenresText(const Locale('en'), separator: ' · '),
      'Cards · Bluffing',
    );
    expect(
      GameInfo.fromJson({
        'id': 'legacy',
        'name': '기존 이름',
      }).localizedName(const Locale('ko')),
      '기존 이름',
    );
    final legacy = GameInfo.fromJson({
      'id': 'legacy',
      'name': '기존 이름',
      'description': '기존 소개',
      'rules': '기존 규칙',
      'genres': ['기존 장르'],
    });
    expect(legacy.localizedDescription(const Locale('en')), '기존 소개');
    expect(legacy.localizedRulesFor(const Locale('en')), '기존 규칙');
    expect(legacy.localizedGenresFor(const Locale('en')), ['기존 장르']);
    final paid = GameInfo.fromJson({
      'id': 'paid',
      'storeProductIds': {
        'appStore': 'mosigame.game.paid',
        'googlePlay': 'mosigame_game_paid',
      },
    });
    expect(paid.storeProductId('appStore'), 'mosigame.game.paid');
    expect(paid.storeProductId('googlePlay'), 'mosigame_game_paid');
  });

  test('classic Yut always shows a two-to-four player range', () {
    final game = GameInfo.fromJson({
      'id': 'yut',
      'name': '윷놀이',
      'minPlayers': 4,
      'maxPlayers': 4,
    });

    expect(game.minPlayers, 2);
    expect(game.maxPlayers, 4);
  });

  test(
    'migrated catalog deduplicates aliases and preserves game routing',
    () async {
      final db = _Database();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      db.catalog.complete(
        _Catalog([
          _Document('liars_poker', {'name': 'old', 'enabled': true}),
          _Document('liars', {'name': 'Liars', 'enabled': true}),
        ]),
      );
      db.owner.complete(
        _Document('user', {
          'ownedGames': ['liars'],
        }),
      );
      final games = await service.fetchGames();
      expect(games, hasLength(1));
      expect(games.single.id, 'liars_poker');
      expect(games.single.name, 'Liars');
      expect(games.single.isOwned, isTrue);
      expect(await service.isGameOwned('liars_poker'), isTrue);
    },
  );

  test(
    'disabled canonical catalog cannot revive through the legacy alias',
    () async {
      final db = _Database();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      db.catalog.complete(
        _Catalog([
          _Document('liars', {'enabled': false}),
          _Document('liars_poker', {'enabled': true}),
        ]),
      );
      db.owner.complete(_Document('user', {}));
      expect(await service.fetchGames(), isEmpty);
    },
  );

  test(
    'catalog entries without enabled true stay out of the library',
    () async {
      final db = _Database();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      db.catalog.complete(
        _Catalog([
          _Document('missing', {'accessType': 'free'}),
          _Document('mistyped', {'accessType': 'free', 'enabled': 'true'}),
          _Document('enabled', {'accessType': 'free', 'enabled': true}),
        ]),
      );
      db.owner.complete(_Document('user', {}));

      expect((await service.fetchGames()).map((game) => game.id), ['enabled']);
    },
  );

  test(
    'existing rooms read the renamed document; fallback only before migration',
    () async {
      final db = _Database();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      db.documents['games/liars'] = _Document('liars', {'name': 'Liars'});
      expect((await service.getGame('liars_poker'))?.id, 'liars_poker');
      expect(db.reads, ['games/liars']);
      db.reads.clear();
      db.documents['games/liars'] = _Document('liars', {}, exists: false);
      db.documents['games/liars_poker'] = _Document('liars_poker', {
        'name': 'old',
      });
      expect((await service.getGame('liars'))?.name, 'old');
      expect(db.reads, ['games/liars', 'games/liars_poker']);
    },
  );

  test(
    'store catalog includes visible paid and disabled games without granting access',
    () async {
      final db = _Database();
      final service = GameService(
        firestore: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      db.catalog.complete(
        _Catalog([
          _Document('hidden', {'storeVisible': false, 'order': 0}),
          _Document('paid', {
            'accessType': 'paid',
            'storeVisible': true,
            'order': 2,
          }),
          _Document('disabled', {
            'enabled': false,
            'storeVisible': true,
            'order': 3,
          }),
          _Document('free', {
            'accessType': 'free',
            'storeVisible': true,
            'order': 1,
          }),
        ]),
      );
      db.owner.complete(_Document('user', {}));

      final games = await service.fetchStoreGames();

      expect(games.map((game) => game.id), ['free', 'paid', 'disabled']);
      expect(games[1].isOwned, isFalse);
      expect(games[1].isAccessible, isFalse);
      expect(games[2].enabled, isFalse);
    },
  );

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

  test(
    'store-scoped provider uses the unfiltered store catalog endpoint',
    () async {
      final service = _ScopedService();
      final provider = GameProvider(
        service: service,
        scope: GameListScope.store,
      );
      addTearDown(provider.dispose);

      await provider.fetchGames();

      expect(service.libraryCalls, 0);
      expect(service.storeCalls, 1);
      expect(provider.games.single.id, 'paid');
    },
  );

  test(
    'default purchase gateway cannot charge or grant an entitlement',
    () async {
      const gateway = DisabledGamePurchaseGateway();
      final game = GameInfo.fromJson({
        'id': 'paid',
        'accessType': 'paid',
        'storeProductIds': {'appStore': 'mosigame.game.paid'},
      });

      expect(gateway.isConfigured, isFalse);
      expect(await gateway.purchase(game), GamePurchaseResult.notConfigured);
      expect(
        await gateway.restorePurchases(),
        GamePurchaseResult.notConfigured,
      );
    },
  );
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

class _ScopedService extends Fake implements GameService {
  var libraryCalls = 0;
  var storeCalls = 0;

  @override
  Future<List<GameInfo>> fetchGames() async {
    libraryCalls++;
    return const [];
  }

  @override
  Future<List<GameInfo>> fetchStoreGames() async {
    storeCalls++;
    return [
      GameInfo.fromJson({'id': 'paid', 'accessType': 'paid'}),
    ];
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
  final documents = <String, DocumentSnapshot<Map<String, dynamic>>>{};
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
    return db.documents.containsKey(path)
        ? Future.value(db.documents[path])
        : db.owner.future;
  }
}

class _Catalog extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Catalog([this.entries]);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>? entries;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      entries ??
      [
        _Document('paid', {'accessType': 'paid', 'enabled': true, 'order': 2}),
        _Document('free', {'accessType': 'free', 'enabled': true, 'order': 1}),
      ];
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value, {this.exists = true});
  @override
  final bool exists;
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
