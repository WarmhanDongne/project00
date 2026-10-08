import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/generated/l10n/app_localizations.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/store/screens/tablet_store_screen.dart';
import 'package:project00/platform/localization/locale_settings.dart';
import 'package:project00/platform/localization/locale_settings_button.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(LocaleSettings settings, Widget home, {double scale = 1}) =>
    LocaleSettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (_, _) => MaterialApp(
          locale: settings.language.locale,
          supportedLocales: AppLanguage.values.map(
            (language) => language.locale,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PlatformTheme.light(locale: settings.language.locale),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FirebaseCore());
  setUpAll(() async {
    await Firebase.initializeApp();
    for (final (family, files) in const [
      ('IBMPlexSansKR', ['IBMPlexSansKR-Regular', 'IBMPlexSansKR-Bold']),
      ('SpaceGrotesk', ['SpaceGrotesk-Bold']),
    ]) {
      final loader = FontLoader('packages/game_kit/$family');
      for (final file in files) {
        loader.addFont(
          rootBundle.load('packages/game_kit/assets/fonts/$file.ttf'),
        );
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'four languages retain script and region independently across launches',
    () async {
      for (final language in AppLanguage.values) {
        final settings = LocaleSettings();
        await settings.load();
        expect(await settings.save(language, 'HK'), isTrue);
        final restored = LocaleSettings();
        await restored.load();
        expect(restored.language, language);
        expect(restored.region, 'HK');
        settings.dispose();
        restored.dispose();
      }
    },
  );

  test(
    'corrupt and unknown local preferences fall back without blocking auth',
    () async {
      for (final raw in [
        '{broken',
        '{"language":"unknown","region":"xx"}',
        '42',
      ]) {
        SharedPreferences.setMockInitialValues({
          LocaleSettings.storageKey: raw,
        });
        final settings = LocaleSettings();
        await settings.load();
        expect(settings.ready, isTrue);
        expect(settings.language, AppLanguage.korean);
        expect(settings.region, 'KR');
        expect(await settings.save(AppLanguage.english, 'xx'), isFalse);
        settings.dispose();
      }
    },
  );

  test('Chinese font fallbacks are native families with distinct scripts', () {
    for (final language in AppLanguage.values.skip(2)) {
      final style = MosiFonts.sans(locale: language.locale);
      expect(style.locale, language.locale);
      expect(
        style.fontFamily,
        contains(language == AppLanguage.traditionalChinese ? 'TC' : 'SC'),
      );
      expect(style.fontFamilyFallback, contains('sans-serif'));
      expect(
        style.fontFamilyFallback!.any(
          (font) => font.startsWith('packages/game_kit/PingFang'),
        ),
        isFalse,
      );
    }
    expect(MosiFonts.sans().fontFamily, 'packages/game_kit/IBMPlexSansKR');
  });

  for (final language in AppLanguage.values) {
    for (final size in [const Size(320, 568), const Size(1024, 768)]) {
      testWidgets(
        '${language.name} modal $size remains usable with enlarged text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final settings = LocaleSettings();
          await settings.load();
          await settings.save(language, 'KR');
          addTearDown(settings.dispose);
          await tester.pumpWidget(
            _app(
              settings,
              const Scaffold(body: Center(child: LocaleSettingsButton())),
              scale: 1.3,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(LocaleSettingsButton));
          await tester.pumpAndSettle();
          final localizations = AppLocalizations.of(
            tester.element(find.byType(LocaleSettingsDialog)),
          )!;
          expect(
            localizations.localeName.replaceAll('_', '-'),
            language.locale.toLanguageTag(),
          );
          await tester.tap(find.byKey(const Key('display-language')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('English').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(MosiButton, localizations.cancel),
          );
          await tester.tap(
            find.widgetWithText(MosiButton, localizations.cancel),
          );
          await tester.pumpAndSettle();
          expect(settings.language, language);
          expect(find.byType(LocaleSettingsDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'save updates open routes and labels while keeping typed login state',
    (tester) async {
      final settings = LocaleSettings();
      await settings.load();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_app(settings, const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'keep-me');
      final state = tester.state(find.byType(LoginScreen));
      final navigator = tester.state(find.byType(Navigator).first);
      final context = tester.element(find.byType(LoginScreen));
      showMosiDialog<void>(
        context: context,
        builder: (_) => LocaleSettingsDialog(settings: settings),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('display-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繁體中文').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('display-region')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('대만').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MosiButton, '저장'));
      await tester.pumpAndSettle();
      expect(settings.language, AppLanguage.traditionalChinese);
      expect(settings.region, 'TW');
      final restored = LocaleSettings();
      await restored.load();
      expect(restored.language, AppLanguage.traditionalChinese);
      expect(restored.region, 'TW');
      restored.dispose();
      expect(find.widgetWithText(MosiButton, '登入'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'keep-me',
      );
      expect(tester.state(find.byType(LoginScreen)), same(state));
      expect(tester.state(find.byType(Navigator).first), same(navigator));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed save keeps dialog open and leaves language unchanged', (
    tester,
  ) async {
    final settings = _FailingSettings();
    await settings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _app(settings, const Scaffold(body: LocaleSettingsButton())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LocaleSettingsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('display-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MosiButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(settings.language, AppLanguage.korean);
    expect(find.byType(LocaleSettingsDialog), findsOneWidget);
  });

  testWidgets('phone globe fits immediately left of profile at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = LocaleSettings();
    await settings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _app(settings, const Scaffold(body: Column(children: [PhoneHeader()]))),
    );
    await tester.pumpAndSettle();
    final globe = tester.getRect(find.byType(LocaleSettingsButton));
    final profile = tester.getRect(find.byType(PhoneProfile));
    expect(globe.width, 44);
    expect(globe.height, 44);
    expect(globe.right, lessThan(profile.left));
    expect(profile.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name} gallery fits at 600px', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = LocaleSettings();
      await settings.load();
      await settings.save(language, 'KR');
      addTearDown(settings.dispose);
      final games = GameProvider()
        ..games = [
          GameInfo.fromJson({'id': 'liars_poker', 'name': '라이어스 포커'}),
        ];
      addTearDown(games.dispose);
      await tester.pumpWidget(
        _app(settings, TabletStoreScreen(gameProvider: games)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _FailingSettings extends LocaleSettings {
  @override
  Future<bool> save(AppLanguage nextLanguage, String nextRegion) async => false;
}

class _FirebaseCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test.appspot.com';
    return apps;
  }
}
