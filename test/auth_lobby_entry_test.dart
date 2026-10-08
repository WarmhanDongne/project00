import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase가 함께 설치한 플랫폼의 공식 테스트 초기화 도구만 사용합니다.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FirebaseCore());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('로그인→가입→취소는 $size에서 route·로고를 유지하고 입력을 복원한다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _Observer();
      await tester.pumpWidget(
        MaterialApp(navigatorObservers: [observer], home: const LoginScreen()),
      );
      await tester.enterText(find.byType(TextField).first, 'sample');
      await tester.enterText(find.byType(TextField).last, 'sample-password');
      final logo = tester.element(find.byType(MosiLogo).first);
      final scaffold = tester.element(find.byType(Scaffold));
      final bounds = tester.getRect(find.byType(MosiLogo).first);
      await tester.tap(find.widgetWithText(MosiButton, '회원가입'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(observer.pushes, 1);
      expect(tester.element(find.byType(Scaffold)), same(scaffold));
      expect(tester.element(find.byType(MosiLogo).first), same(logo));
      expect(tester.getRect(find.byType(MosiLogo).first), bounds);
      expect(find.text('인증 메일 보내기'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
      await tester.tap(find.text('중단하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(RegisterScreen), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'sample',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'sample-password',
      );
      expect(observer.pushes, 2); // 앱 route와 명시적 중단 확인 모달만.
      expect(tester.element(find.byType(Scaffold)), same(scaffold));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('서버 가입 단계가 비밀번호→프로필로 바뀌어도 인증 바탕은 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final users = StreamController<User?>();
    final onboarding = _Onboarding();
    final observer = _Observer();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: AuthGate(
          userChanges: users.stream,
          onboardingService: onboarding,
        ),
      ),
    );
    users.add(_User());
    await tester.pump();
    onboarding.states.add(
      const UserOnboarding(
        uid: 'test',
        status: OnboardingStatus.settingPassword,
        provider: OnboardingProvider.emailLink,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final scaffold = tester.element(find.byType(Scaffold));
    final logo = tester.element(find.byType(MosiLogo));
    expect(find.text('비밀번호 재입력'), findsNWidgets(2)); // 라벨과 입력 힌트.
    onboarding.states.add(
      const UserOnboarding(
        uid: 'test',
        status: OnboardingStatus.settingProfile,
        provider: OnboardingProvider.emailLink,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('가입 완료'), findsOneWidget);
    expect(observer.pushes, 1);
    expect(tester.element(find.byType(Scaffold)), same(scaffold));
    expect(tester.element(find.byType(MosiLogo)), same(logo));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(users.close);
    addTearDown(onboarding.states.close);
  });

  testWidgets('인증 대기 화면이 퇴장 중이어도 지난 타이머가 로그인 상태를 지우지 않는다', (tester) async {
    final users = StreamController<User?>();
    var timeouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: users.stream,
          onboardingService: _Onboarding(),
          onAuthRestoreTimeout: () => timeouts++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 7900));
    users.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(timeouts, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(users.close);
  });

  testWidgets('입장 중 중복 요청을 막고 서버 거절을 버튼 바로 위에 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    final button = find.widgetWithText(MosiButton, '입장하기');
    await tester.tap(button);
    await tester.pump();
    expect(service.calls, 1);
    expect(
      roomCharacters.map((character) => character.id),
      contains(service.sentCharacterId),
    );
    expect(find.text('입장하는 중…'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is MosiButton && widget.label == '입장하기',
      ),
    );
    expect(service.calls, 1);
    service.response.completeError(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: '올바른 캐릭터를 선택해주세요.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final error = find.text('올바른 캐릭터를 선택해주세요.');
    expect(error, findsOneWidget);
    final errorRect = tester.getRect(error);
    final buttonRect = tester.getRect(find.widgetWithText(MosiButton, '입장하기'));
    expect(errorRect.top, greaterThan(0));
    expect(errorRect.bottom, lessThan(buttonRect.top));
    expect(buttonRect.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class _FirebaseCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test.appspot.com';
    return apps;
  }
}

class _User implements User {
  @override
  String get uid => 'test';
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Onboarding extends OnboardingService {
  final states = StreamController<UserOnboarding?>();
  @override
  Stream<UserOnboarding?> watch(String uid) => states.stream;
}

class _RoomProvider extends RoomProvider {
  _RoomProvider(_RoomService service)
    : super(service: service, gameService: _GameService());
  @override
  void listenRoomPreview(String roomCode) {}
  @override
  void stopRoomPreview() {}
}

class _RoomService implements RoomService {
  int calls = 0;
  String? sentCharacterId;
  final response = Completer<void>();
  @override
  Future<void> joinRoom(
    String code,
    String nickname, {
    required String characterId,
    bool preserveProfile = false,
  }) {
    calls++;
    sentCharacterId = characterId;
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
