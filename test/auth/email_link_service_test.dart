import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';

void main() {
  late _Auth auth;
  late _Functions functions;
  late OnboardingService service;
  setUp(() {
    auth = _Auth();
    functions = _Functions(auth.events);
    service = OnboardingService(
      auth: auth,
      firestore: _Firestore(),
      functions: functions,
    );
  });

  test('새 가입은 계정 생성 후 웹 인증 메일을 보내고 확인 시 토큰을 갱신한다', () async {
    await service.createPasswordAccount('signup@example.com', 'Abcd12!');
    expect(auth.events, ['createPasswordAccount']);
    expect(auth.password, 'Abcd12!');
    await service.preparePasswordVerification();
    expect(functions.parameters, {'provider': 'legacyPassword'});
    await service.sendPasswordVerification();
    expect(auth.events.last, 'sendEmailVerification');
    expect(await service.refreshEmailVerification(), isFalse);
    expect(auth.events.last, 'reload');
    (auth.currentUser as _User).verified = true;
    expect(await service.refreshEmailVerification(), isTrue);
    expect(auth.events.last, 'refreshToken');
    expect(auth.events, isNot(contains('signIn')));
  });

  test('미로그인 상태에서 인증을 성공한 것처럼 처리하지 않는다', () async {
    await expectLater(
      service.sendPasswordVerification(),
      throwsA(isA<AuthServiceException>()),
    );
    await expectLater(
      service.refreshEmailVerification(),
      throwsA(isA<AuthServiceException>()),
    );
  });

  test('중복 계정 생성은 로그인 안내로 반환한다', () async {
    auth.failure = FirebaseAuthException(code: 'email-already-in-use');
    await expectLater(
      service.createPasswordAccount('signup@example.com', 'Abcd12!'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.code,
          'code',
          'email-already-in-use',
        ),
      ),
    );
    expect(auth.currentUser, isNull);
  });

  test('기존 링크 가입 메일은 앱에서 처리하는 링크와 양 플랫폼 식별자를 전달한다', () async {
    await service.sendEmailLink('signup@example.com');
    expect(auth.email, 'signup@example.com');
    final settings = auth.settings!;
    expect(settings.handleCodeInApp, isTrue);
    expect(settings.androidPackageName, 'com.warmhandongne.msg');
    expect(settings.iOSBundleId, 'com.warmhandongne.msg');
    expect(
      settings.url,
      'https://project0000-ec01e.firebaseapp.com/auth/email-link',
    );
  });

  test('링크 인증이 끝난 뒤 서버 가입 단계를 시작한다', () async {
    await service.completeEmailLink(email: 'signup@example.com', link: 'valid');
    expect(auth.events, ['signIn', 'beginOnboarding']);
    expect(auth.email, 'signup@example.com');
    expect(auth.link, 'valid');
  });

  test('일반 URL은 인증과 서버 가입 요청을 보내지 않는다', () async {
    auth.valid = false;
    await expectLater(
      service.completeEmailLink(email: 'signup@example.com', link: 'invalid'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.code,
          'code',
          'invalid-action-code',
        ),
      ),
    );
    expect(auth.events, isEmpty);
  });

  for (final code in ['expired-action-code', 'invalid-action-code']) {
    test('$code 링크는 서버 가입 단계로 진행하지 않는다', () async {
      auth.failure = FirebaseAuthException(code: code);
      await expectLater(
        service.completeEmailLink(email: 'signup@example.com', link: 'valid'),
        throwsA(
          isA<AuthServiceException>().having(
            (error) => error.code,
            'code',
            code,
          ),
        ),
      );
      expect(auth.events, ['signIn']);
    });
  }

  test('메일 전송 실패를 성공으로 처리하지 않는다', () async {
    auth.failure = FirebaseAuthException(code: 'network-request-failed');
    await expectLater(
      service.sendEmailLink('signup@example.com'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.code,
          'code',
          'network-request-failed',
        ),
      ),
    );
  });

  test('가입 요청의 인증 지연은 토큰 갱신 후 한 번만 재시도한다', () async {
    functions.failures = 1;
    await service.completeEmailLink(email: 'signup@example.com', link: 'valid');
    expect(auth.events, [
      'signIn',
      'beginOnboarding',
      'refreshToken',
      'beginOnboarding',
    ]);
  });

  test('인증 재시도 실패는 무한 로딩 대신 호출자에게 전달한다', () async {
    functions.failures = 2;
    await expectLater(
      service.completeEmailLink(email: 'signup@example.com', link: 'valid'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
    expect(auth.events, [
      'signIn',
      'beginOnboarding',
      'refreshToken',
      'beginOnboarding',
    ]);
  });
}

class _Auth implements FirebaseAuth {
  final events = <String>[];
  bool valid = true;
  String? email;
  String? password;
  String? link;
  ActionCodeSettings? settings;
  FirebaseAuthException? failure;
  User? _user;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    events.add('createPasswordAccount');
    this.email = email;
    this.password = password;
    _user = _User(events);
    return _Credential();
  }

  @override
  User? get currentUser => _user;
  @override
  bool isSignInWithEmailLink(String link) => valid;
  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) async {
    if (failure != null) throw failure!;
    this.email = email;
    settings = actionCodeSettings;
  }

  @override
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    events.add('signIn');
    if (failure != null) throw failure!;
    this.email = email;
    link = emailLink;
    _user = _User(events);
    return _Credential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.events);
  final List<String> events;
  bool verified = false;
  @override
  String get uid => 'test';
  @override
  bool get emailVerified => verified;
  @override
  Future<void> reload() async {
    events.add('reload');
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    expect(settings, isNull); // 기본 웹 인증, sign-in 딥링크 아님.
    events.add('sendEmailVerification');
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    events.add('refreshToken');
    return 'test';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Functions implements FirebaseFunctions {
  _Functions(this.events);
  final List<String> events;
  int failures = 0;
  dynamic parameters;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(this, name);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Callable implements HttpsCallable {
  _Callable(this.owner, this.name);
  final _Functions owner;
  final String name;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.parameters = parameters;
    owner.events.add(name);
    if (owner.failures-- > 0) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'test',
      );
    }
    return _Result<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
