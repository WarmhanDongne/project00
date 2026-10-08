import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/store/screens/tablet_store_screen.dart';
import 'package:project00/platform/home/store/store_motion.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';
import 'package:project00/platform/profile/widgets/tablet_profile_modal.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FirebaseCore());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('프로필에서 내 색을 제거하고 탈퇴 취소/실패/성공을 처리한다', (tester) async {
    final auth = _Auth();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMosiDialog<bool>(
                context: context,
                builder: (_) => TabletProfileModal(authService: auth),
              ),
              child: const Text('프로필 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('프로필 열기'));
    await tester.pumpAndSettle();
    expect(find.text('내 색'), findsNothing);
    // 시안(ProfileModal): '사진 변경'은 사진 단추의 접근성 이름입니다.
    expect(find.bySemanticsLabel('사진 변경'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).shadow,
      isFalse,
    );
    expect(
      tester.widget<MosiDialogFrame>(find.byType(MosiDialogFrame)).shadowOffset,
      // 시안(ProfileModal)은 판에 10px 남색 오프셋 그림자를 둡니다.
      10,
    );
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    expect(auth.deletions, 0);
    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
    expect(auth.deletions, 0);
    expect(find.byType(TabletProfileModal), findsOneWidget);
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.deletions, 1);
    final deletionButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '탈퇴 확인 중…'),
    );
    expect(deletionButton.onPressed, isNull);
    auth.pending.completeError(
      const AuthServiceException('unavailable', '연결 실패'),
    );
    await tester.pumpAndSettle();
    expect(find.text('연결 실패'), findsOneWidget);
    expect(find.byType(TabletProfileModal), findsOneWidget);
    auth.pending = Completer<void>();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pump();
    auth.pending.complete();
    await tester.pumpAndSettle();
    expect(auth.deletions, 2);
    expect(find.byType(TabletProfileModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('휴대폰에서 프로필 키보드가 올라와도 저장·탈퇴에 스크롤로 접근한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 310),
          ),
          child: Scaffold(
            body: Center(child: TabletProfileModal(authService: _Auth())),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final owned in [true, false]) {
    testWidgets('상점 실제 보유=$owned를 표시하고 선택 게임 ID를 선반으로 반환한다', (tester) async {
      final games = GameProvider(service: _Games())
        ..games = [
          GameInfo.fromJson({
            'id': 'final_call',
            'name': '파이널콜',
            'isOwned': owned,
          }),
        ];
      addTearDown(games.dispose);
      String? returned;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<String>(
                    PageRouteBuilder<String>(
                      transitionDuration: const Duration(milliseconds: 480),
                      pageBuilder: (_, _, _) =>
                          TabletStoreScreen(gameProvider: games),
                    ),
                  );
                },
                child: const Text('상점 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('상점 열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('₩3,900'), findsNothing);
      await tester.tap(find.text('파이널콜').first);
      await tester.pump();
      expect(
        find.textContaining(owned ? '· 보유 중' : '· 무료', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('선반에서 하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(returned, 'final_call');
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(800, 600),
    const Size(1024, 768),
    const Size(1194, 834),
    const Size(600, 900),
  ]) {
    testWidgets('상점 $size는 바깥 빈 띠 없이 채우고 로비 머리줄 위치·버튼 높이를 유지한다', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final games = GameProvider(service: _Games())
        ..games = [
          GameInfo.fromJson({'id': 'liars_poker', 'name': '라이어스 포커'}),
        ];
      addTearDown(games.dispose);
      await tester.pumpWidget(
        MaterialApp(home: TabletStoreScreen(gameProvider: games)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final floor = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == MosiColors.violet,
      );
      final floorRect = tester.getRect(floor);
      expect(floorRect.left, 0);
      expect(floorRect.right, size.width);
      expect(floorRect.bottom, size.height);
      final backRect = tester.getRect(find.widgetWithText(MosiButton, '선반'));
      final restoreRect = tester.getRect(
        find.widgetWithText(MosiButton, '구매 내역 복원'),
      );
      final inset = size.width < 1000 ? 16.0 : 32.0;
      expect(backRect.left, inset);
      expect(backRect.height, 44);
      expect(restoreRect.right, size.width - inset);
      expect(restoreRect.top, backRect.top);
      expect(tester.getCenter(find.text('모시 게임 미술관')).dx, size.width / 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('상점은 결제·알림 신청·음악 재생을 완료한 것처럼 표시하지 않는다', (tester) async {
    final games = GameProvider(service: _Games())
      ..games = [
        GameInfo.fromJson({'id': 'liars_poker', 'name': '라이어스 포커'}),
      ];
    addTearDown(games.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TabletStoreScreen(gameProvider: games)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('구매 준비 중'), findsOneWidget);
    await tester.tap(find.text('다음 전시'));
    await tester.pump();
    expect(find.text('공개 준비 중'), findsOneWidget);
    await tester.tap(find.text('공개 준비 중'));
    await tester.pump();
    expect(find.text('알림 켜짐'), findsNothing);
    expect(find.textContaining('알림 신청은 준비'), findsOneWidget);
    await tester.tap(find.text('마피아').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('배경 음악 · 준비 중'), findsOneWidget);
    expect(find.text('배경 음악 · 재생 중'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상점 등장 시간축에서 조명이 먼저 내려오고 액자는 차례로 등장한다', (tester) async {
    final games = GameProvider(service: _Games())
      ..games = [
        GameInfo.fromJson({'id': 'liars_poker', 'name': '라이어스 포커'}),
      ];
    addTearDown(games.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(milliseconds: 480),
                  pageBuilder: (_, _, _) =>
                      TabletStoreScreen(gameProvider: games),
                ),
              ),
              child: const Text('상점'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('상점'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    double opacity(StoreEntrance entry) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byWidget(entry),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    final entries = tester
        .widgetList<StoreEntrance>(find.byType(StoreEntrance))
        .toList();
    final lamp = entries.firstWhere((w) => w.offset.dy == -110);
    final first = entries.firstWhere((w) => w.start == .15);
    final last = entries.firstWhere((w) => w.start > .38 && w.start < .4);
    expect(opacity(lamp), greaterThan(opacity(first)));
    expect(opacity(first), greaterThan(opacity(last)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(last), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('음소거 후 설정을 닫았다 열어도 이전 음량으로 복원한다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sound = _Sound();
    final room = _Room();
    addTearDown(sound.dispose);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TabletGameSettingsDialog(provider: room),
                ),
                child: const Text('설정 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 음소거'));
    await tester.pump();
    expect(sound.masterVolume, 0);
    await tester.tap(find.byType(MosiSquareCloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('소리 다시 켜기'));
    await tester.pump();
    expect(sound.masterVolume, 30);
    expect(tester.takeException(), isNull);
  });

  for (final (id, name) in [
    ('liars_poker', '라이어스 포커'),
    ('final_call', '파이널콜'),
    ('mafia', '마피아'),
    ('holdem', '텍사스 홀덤'),
  ]) {
    testWidgets('$name 설정에 책 커버를 게임 포스터로 표시한다', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sound = _Sound();
      final room = _Room(game: GameInfo.fromJson({'id': id, 'name': name}));
      addTearDown(sound.dispose);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SoundProvider>.value(
          value: sound,
          child: MaterialApp(
            home: Scaffold(body: TabletGameSettingsDialog(provider: room)),
          ),
        ),
      );

      final cover = tester.widget<MosiGameCover>(find.byType(MosiGameCover));
      expect(cover.gameId, id);
      expect(cover.width, 170);
      if (id == 'holdem') {
        final image = tester.widget<Image>(
          find.byKey(const Key('holdem-cardbox-cover')),
        );
        expect(
          (image.image as AssetImage).assetName,
          'packages/game_kit/assets/images/covers/holdem_cardbox.webp',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _FirebaseCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test.appspot.com';
    return apps;
  }
}

class _Auth implements FirebaseAuthService {
  int deletions = 0;
  Completer<void> pending = Completer<void>();
  @override
  Future<void> deleteAccount() {
    deletions++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Games implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sound extends SoundProvider {
  _Sound() : super(preferences: _Preferences());
  double volume = 30;
  @override
  double get masterVolume => volume;
  @override
  void setMasterVolume(double value) {
    volume = value;
    notifyListeners();
  }
}

class _Room extends GameRoomContext {
  _Room({this.game});

  final GameRoomMetadata? game;

  @override
  String? get roomCode => null;
  @override
  GameRoomMetadata? get selectedGame => game;
  @override
  List<GameRoomPlayer> get players => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
