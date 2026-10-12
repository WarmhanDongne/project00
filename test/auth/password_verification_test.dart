import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/screens/email_verification_screen.dart';
import 'package:project00/platform/auth/screens/profile_setup_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_Core());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SignupConsentStore().save(
      const SignupConsents(age14: true, terms: true, privacy: true),
    );
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('새 가입은 $size에서 비밀번호 검증 후 계정을 한 번 만들고 실패를 표시한다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Service();
      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(onboardingService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final button = find.widgetWithText(MosiButton, '계정 만들고 인증하기');
      expect(tester.widget<MosiButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(0), 'NewUser');
      await tester.enterText(find.byType(TextField).at(1), 'Abcd12!');
      await tester.enterText(find.byType(TextField).at(2), 'Abcd12?');
      await tester.pump();
      expect(tester.widget<MosiButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(2), 'Abcd12!');
      await tester.pump();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      expect(service.creates, 1);
      expect(service.email, 'newuser@gmail.com');
      expect(service.password, 'Abcd12!');
      expect(service.sent, 0); // 인증 메일은 계정 생성 후 gate에서 보냅니다.
      service.created.completeError(
        const AuthServiceException(
          'email-already-in-use',
          '이미 가입된 이메일입니다. 로그인해주세요.',
        ),
      );
      await tester.pump();
      expect(find.text('이미 가입된 이메일입니다. 로그인해주세요.'), findsOneWidget);
      expect(tester.widget<MosiButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('인증 메일은 준비 완료 후 보내고 미인증·앱 복귀·중복 탭을 처리한다', (tester) async {
    final service = _Service();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'test@example.com',
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.events, ['prepare', 'refresh', 'send']);
    expect(find.textContaining('인증 메일을 보냈어요'), findsOneWidget);
    service.check = Completer<bool>();
    await tester.tap(find.text('인증했어요'));
    await tester.pump();
    await tester.tap(find.text('인증했어요'));
    await tester.tap(find.text('인증 메일 다시 보내기'));
    expect(service.events.where((event) => event == 'refresh').length, 2);
    expect(service.sent, 1);
    service.check!.complete(false);
    await tester.pump();
    expect(find.textContaining('아직 인증이 확인되지'), findsOneWidget);
    service.check = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.events.where((event) => event == 'refresh').length, 3);
    expect(service.sent, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('가입 준비나 메일 발송 실패는 재시도할 수 있다', (tester) async {
    final service = _Service()..prepareFails = true;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'test@example.com',
          service: service,
        ),
      ),
    );
    await tester.pump();
    expect(service.sent, 0);
    expect(find.text('준비 실패'), findsOneWidget);
    service.prepareFails = false;
    service.sendFails = true;
    await tester.tap(find.text('인증 메일 다시 보내기'));
    await tester.pump();
    expect(find.text('메일 실패'), findsOneWidget);
    service.sendFails = false;
    await tester.tap(find.text('인증 메일 다시 보내기'));
    await tester.pump();
    expect(find.textContaining('인증 메일을 보냈어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('앱 재시작의 미인증 계정은 인증 대기로 복원되고 인증 후 프로필로 간다', (tester) async {
    final users = StreamController<User?>();
    addTearDown(users.close);
    final service = _Service();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(userChanges: users.stream, onboardingService: service),
      ),
    );
    users.add(_User(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(service.watches, 0);
    users.add(_User(true));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(EmailVerificationScreen), findsNothing);
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing); // 비밀번호를 다시 묻지 않습니다.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Service implements OnboardingService {
  int creates = 0, sent = 0, watches = 0;
  String? email, password;
  bool prepareFails = false, sendFails = false;
  final events = <String>[];
  final created = Completer<void>();
  Completer<bool>? check;
  @override
  Future<void> createPasswordAccount(String email, String password) {
    creates++;
    this.email = email;
    this.password = password;
    return created.future;
  }

  @override
  Future<void> preparePasswordVerification() async {
    events.add('prepare');
    if (prepareFails) throw const AuthServiceException('unavailable', '준비 실패');
  }

  @override
  Future<bool> refreshEmailVerification() {
    events.add('refresh');
    return check?.future ?? Future.value(false);
  }

  @override
  Future<void> sendPasswordVerification() async {
    events.add('send');
    if (sendFails) throw const AuthServiceException('unavailable', '메일 실패');
    sent++;
  }

  @override
  Stream<UserOnboarding?> watch(String uid) {
    watches++;
    return Stream.value(
      UserOnboarding(
        uid: uid,
        status: OnboardingStatus.settingProfile,
        provider: OnboardingProvider.legacyPassword,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  bool get isAnonymous => false;
  _User(this.emailVerified);
  @override
  final bool emailVerified;
  @override
  String get uid => 'test';
  @override
  String? get email => 'test@example.com';
  @override
  List<UserInfo> get providerData => [_PasswordProvider()];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PasswordProvider implements UserInfo {
  @override
  String get providerId => 'password';
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
