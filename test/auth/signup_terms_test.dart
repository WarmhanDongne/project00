import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/signup_terms_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('필수 세 항목에 모두 동의해야 계속할 수 있고 마케팅은 선택이다', (tester) async {
    _phone(tester);
    SignupConsents? agreed;
    await tester.pumpWidget(
      _host(SignupTermsView(onAgreed: (consents) => agreed = consents)),
    );
    expect(find.text('필수 항목 3개에 동의해 주세요'), findsOneWidget);
    expect(find.text('동의하고 계속하기'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('terms-age14')));
    await tester.tap(find.byKey(const ValueKey('terms-terms')));
    await tester.pump();
    expect(find.text('필수 항목 1개에 동의해 주세요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('terms-privacy')));
    await tester.pump();

    await tester.tap(find.text('동의하고 계속하기'));
    expect(agreed?.requiredAgreed, isTrue);
    expect(agreed?.marketing, isFalse);
  });

  testWidgets('전체 동의는 선택 항목까지 한 번에 켜고 다시 누르면 모두 끈다', (tester) async {
    _phone(tester);
    SignupConsents? agreed;
    await tester.pumpWidget(
      _host(SignupTermsView(onAgreed: (consents) => agreed = consents)),
    );
    await tester.tap(find.byKey(const ValueKey('terms-all')));
    await tester.pump();
    await tester.tap(find.text('동의하고 계속하기'));
    expect(agreed?.allAgreed, isTrue);

    await tester.tap(find.byKey(const ValueKey('terms-all')));
    await tester.pump();
    expect(find.text('필수 항목 3개에 동의해 주세요'), findsOneWidget);
  });

  testWidgets('전문 보기에서 확인하고 동의하면 그 항목이 켜진다', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(SignupTermsView(onAgreed: (_) {})));
    await tester.tap(find.byTooltip('이용약관 동의 전문 보기'));
    await tester.pumpAndSettle();
    expect(find.text('모시겜 이용약관'), findsOneWidget);
    expect(find.text('검토 전 초안'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('legal-document-agree')));
    await tester.pumpAndSettle();
    expect(find.text('필수 항목 2개에 동의해 주세요'), findsOneWidget);

    await tester.tap(find.byTooltip('개인정보 수집·이용 동의 전문 보기'));
    await tester.pumpAndSettle();
    expect(find.text('모시겜 개인정보 처리방침'), findsOneWidget);
    expect(find.text('검토 전 초안'), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('필수 항목 2개에 동의해 주세요'), findsOneWidget);
  });

  test('기기 보관 동의는 지금 약관 버전에 필수 항목까지 동의한 것만 쓴다', () async {
    final store = SignupConsentStore();
    expect(await store.read(), isNull);
    await store.save(
      const SignupConsents(age14: true, terms: true, privacy: true),
    );
    final saved = await store.read();
    expect(saved?.requiredAgreed, isTrue);
    expect(saved?.marketing, isFalse);

    SharedPreferences.setMockInitialValues({
      'auth.signupConsents':
          '{"version":"2000-01-01","age14":true,"terms":true,"privacy":true}',
    });
    expect(await store.read(), isNull);
    SharedPreferences.setMockInitialValues({
      'auth.signupConsents':
          '{"version":"${SignupTermsVersion.current}","age14":true,"terms":false,"privacy":true}',
    });
    expect(await store.read(), isNull);
    await store.clear();
    expect(await store.read(), isNull);
  });

  testWidgets('새 이메일 가입은 약관 동의부터 시작하고 동의하면 이메일 단계로 넘어간다', (tester) async {
    _phone(tester);
    final store = SignupConsentStore();
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          onboardingService: _Onboarding(),
          consentStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('모시겜을 시작하기 전에\n약관을 확인해 주세요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('terms-all')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('terms-continue')));
    await tester.tap(find.byKey(const ValueKey('terms-continue')));
    await tester.pumpAndSettle();

    expect(find.text('모시겜을 시작하기 전에\n약관을 확인해 주세요'), findsNothing);
    expect((await store.read())?.allAgreed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 동의하고 돌아온 가입은 약관을 다시 묻지 않는다', (tester) async {
    _phone(tester);
    final store = SignupConsentStore();
    await store.save(
      const SignupConsents(age14: true, terms: true, privacy: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          onboardingService: _Onboarding(),
          consentStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('모시겜을 시작하기 전에\n약관을 확인해 주세요'), findsNothing);
    expect(find.byType(SignupTermsView), findsNothing);
  });

  test('가입을 마칠 때 약관 동의를 버전과 함께 서버에 보낸다', () async {
    final functions = _Functions();
    final service = OnboardingService(
      auth: _Auth(),
      functions: functions,
      firestore: _Firestore(),
    );
    await service.completeProfile(
      nickname: '모시',
      consents: const SignupConsents(
        age14: true,
        terms: true,
        privacy: true,
        marketing: true,
      ),
    );
    expect(functions.name, 'completeOnboardingProfile');
    expect(functions.data?['consents'], {
      'version': SignupTermsVersion.current,
      'age14': true,
      'terms': true,
      'privacy': true,
      'marketing': true,
    });
  });
}

class _Onboarding implements OnboardingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Functions implements FirebaseFunctions {
  String? name;
  Map<String, dynamic>? data;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    this.name = name;
    return _Callable(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Callable implements HttpsCallable {
  _Callable(this.functions);
  final _Functions functions;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    functions.data = Map<String, dynamic>.from(parameters as Map);
    return _Result<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
