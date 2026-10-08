import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/generated/l10n/app_localizations.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';
import 'package:project00/platform/localization/locale_settings.dart';
import 'package:project00/platform/theme/platform_theme.dart';

Widget _app(String game, Locale locale, {double scale = 1}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLanguage.values.map((language) => language.locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: PlatformTheme.light(locale: locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 694,
            height: 560,
            child: buildGamePlayPreview(game),
          ),
        ),
      ),
    ),
  ),
);

Iterable<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, files) in const [
      ('IBMPlexSansKR', ['IBMPlexSansKR-Regular', 'IBMPlexSansKR-Bold']),
      ('SpaceGrotesk', ['SpaceGrotesk-Bold']),
      ('PlayfairDisplay', ['PlayfairDisplay-Black']),
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

  for (final game in ['liars_poker', 'final_call', 'mafia', 'holdem']) {
    for (final language in AppLanguage.values) {
      testWidgets(
        '$game ${language.name} translates across the preview timeline',
        (tester) async {
          await tester.pumpWidget(_app(game, language.locale));
          await tester.pump();
          final t = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
          final expected = switch (game) {
            'liars_poker' => t.previewTwoAces,
            'final_call' => t.previewSameColor,
            'mafia' => t.previewNight,
            _ => t.previewRaiseClaim,
          };
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 1700));
            expect(_texts(tester), contains(expected));
            if (language != AppLanguage.korean) {
              expect(
                _texts(tester).where((text) => RegExp('[가-힣]').hasMatch(text)),
                isEmpty,
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$game / ${language.name} frame $frame',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('holdem preview puts cards above actions in all phone frames', (
    tester,
  ) async {
    await tester.pumpWidget(_app('holdem', const Locale('en')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2400));
    for (final id in ['sara', 'minjun', 'harin']) {
      final hand = tester.getRect(
        find.byKey(ValueKey('preview-holdem-hand-$id')),
      );
      final action = tester.getRect(
        find.byKey(ValueKey('preview-holdem-action-$id')),
      );
      expect(
        hand.center.dy,
        lessThan(action.top),
        reason: '$id hand must sit above the lower controls',
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'language changes update an open preview without resetting its hand',
    (tester) async {
      await tester.pumpWidget(_app('holdem', const Locale('ko')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 7400));
      expect(find.text('POT 830'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          'holdem',
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
      );
      await tester.pump();
      expect(find.text('底池 830'), findsOneWidget);
      expect(find.text('同花贏得 +830'), findsOneWidget);
      expect(find.text('플러시로 +830'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
