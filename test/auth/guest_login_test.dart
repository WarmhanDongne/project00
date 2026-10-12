import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/screens/guest_setup_screen.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/email_verification_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:project00/platform/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_Core());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('게스트 로그인은 Firebase 익명 API를 호출하고 비활성 오류를 안내한다', () async {
    final auth = _Auth();
    final service = FirebaseAuthService(auth: auth);
    await service.signInAsGuest();
    expect(auth.calls, 1);
    auth.fail = true;
    await expectLater(
      service.signInAsGuest(),
      throwsA(
        isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('활성화'),
        ),
      ),
    );
  });

  test('게스트 준비는 약관만 서버에 보내고 실패를 재시도 가능한 오류로 전달한다', () async {
    final functions = _Functions();
    final service = OnboardingService(
      auth: _Auth(),
      firestore: _Firestore(),
      functions: functions,
    );
    const consents = SignupConsents(age14: true, terms: true, privacy: true);
    await service.completeGuest(consents);
    expect(functions.name, 'completeGuestOnboarding');
    expect(functions.data, {'consents': consents.toJson()});
    functions.fail = true;
    await expectLater(
      service.completeGuest(consents),
      throwsA(isA<AuthServiceException>()),
    );
  });

  test('게스트 프로필 수정은 Google 동기화 대신 완료된 익명 프로필을 갱신한다', () async {
    final functions = _Functions();
    final service = FirebaseAuthService(auth: _Auth(), functions: functions);
    await service.createUserDocument();
    expect(functions.name, 'completeOnboardingProfile');
    expect(functions.data, {'nickname': '게스트abc123', 'profileImageUrl': null});
  });

  for (final size in [const Size(390, 844), const Size(1194, 834)]) {
    testWidgets('게스트 버튼은 Google 위에 있고 중복 요청·실패를 처리한다 ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _LoginService();
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: service)),
      );
      final guest = find.byKey(const Key('login-guest-button'));
      final google = find.byKey(const Key('login-google-button'));
      expect(
        tester.getTopLeft(guest).dy,
        lessThan(tester.getTopLeft(google).dy),
      );
      await tester.ensureVisible(guest);
      await tester.tap(guest);
      await tester.pump();
      await tester.tap(guest);
      expect(service.calls, 1);
      expect(tester.widget<MosiButton>(guest).onPressed, isNull);
      service.pending.completeError(
        const AuthServiceException('unavailable', '게스트 오류'),
      );
      await tester.pump();
      expect(find.text('게스트 오류'), findsOneWidget);
      expect(tester.widget<MosiButton>(guest).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('게스트 약관 필수 동의·중복 방지·실패 재시도가 작동한다 ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _Onboarding();
      await tester.pumpWidget(
        MaterialApp(home: GuestSetupScreen(service: service)),
      );
      expect(find.byKey(const ValueKey('terms-continue')), findsNothing);
      for (final key in ['terms-age14', 'terms-terms', 'terms-privacy']) {
        final row = find.byKey(ValueKey(key));
        await tester.ensureVisible(row);
        await tester.tap(
          find
              .descendant(of: row, matching: find.byType(GestureDetector))
              .first,
        );
        await tester.pump();
      }
      final next = find.byKey(const ValueKey('terms-continue'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      await tester.tap(next);
      expect(service.calls, 1);
      expect(service.consents!.requiredAgreed, isTrue);
      expect(service.consents!.marketing, isFalse);
      service.pending.completeError(
        const AuthServiceException('unavailable', '준비 실패'),
      );
      await tester.pump();
      expect(find.text('준비 실패'), findsOneWidget);
      service.pending = Completer<void>();
      await tester.ensureVisible(next);
      await tester.tap(next);
      expect(service.calls, 2);
      service.pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await service.states.close();
    });
  }

  for (final restored in [false, true]) {
    testWidgets('게스트 gate는 서버 완료 후 로비에 진입하고 복원한다 (기존=$restored)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final users = StreamController<User?>();
      final service = _Onboarding();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(userChanges: users.stream, onboardingService: service),
        ),
      );
      users.add(_Guest());
      await tester.pump();
      const complete = UserOnboarding(
        uid: 'guest',
        status: OnboardingStatus.complete,
        provider: OnboardingProvider.anonymous,
      );
      service.states.add(restored ? complete : null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(EmailVerificationScreen), findsNothing);
      if (!restored) {
        expect(find.byType(GuestSetupScreen), findsOneWidget);
        expect(find.byType(Home), findsNothing);
        service.states.add(complete);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(find.byType(Home), findsOneWidget);
      users.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(users.close());
      unawaited(service.states.close());
    });
  }
}

class _LoginService extends FirebaseAuthService {
  int calls = 0;
  final pending = Completer<void>();
  @override
  Future<void> signInAsGuest() {
    calls++;
    return pending.future;
  }
}

class _Onboarding implements OnboardingService {
  final states = StreamController<UserOnboarding?>.broadcast();
  Completer<void> pending = Completer<void>();
  int calls = 0;
  SignupConsents? consents;
  @override
  Stream<UserOnboarding?> watch(String uid) => states.stream;
  @override
  Future<void> completeGuest(SignupConsents value) {
    calls++;
    consents = value;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guest implements User {
  @override
  String get uid => 'guest';
  @override
  bool get isAnonymous => true;
  @override
  bool get emailVerified => false;
  @override
  String? get displayName => '게스트abc123';
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  int calls = 0;
  bool fail = false;
  @override
  User get currentUser => _Guest();
  @override
  Future<UserCredential> signInAnonymously() async {
    calls++;
    if (fail) throw FirebaseAuthException(code: 'operation-not-allowed');
    return _Credential();
  }

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

class _Functions implements FirebaseFunctions {
  String? name;
  dynamic data;
  bool fail = false;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    this.name = name;
    return _Callable(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Callable implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.data = parameters;
    if (owner.fail) {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
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

class _Core extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test.appspot.com';
    return apps;
  }
}
