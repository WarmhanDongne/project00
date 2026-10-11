import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/player_layouts/widgets/player_layout_editor.dart';

const _gameColor = Color(0xFF136A90);
const _imageColor = Color(0xFF735732);
final _layout = PlayerLayoutModel(
  players: List.generate(
    4,
    (i) => PlayerLayoutPlayer(
      uid: 'player-$i',
      nickname: 'P$i',
      characterId: 'bear',
      seatIndex: i,
    ),
  ),
);

Future<void> _expectEdges(
  WidgetTester tester,
  GlobalKey key,
  Color color,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    // Include the old header strip, safe insets and all four corners.
    for (final point in [
      const Offset(1, 1),
      Offset(image.width - 2, 1),
      Offset(1, image.height - 2),
      Offset(image.width - 2, image.height - 2),
      Offset(image.width / 2, 1),
      Offset(image.width / 2, image.height - 2),
      const Offset(1, 50),
      Offset(image.width - 2, 50),
    ]) {
      final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
      final actual = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      expect(actual, color, reason: 'uncovered viewport pixel $point');
    }
    image.dispose();
  });
}

Future<MemoryImage> _background() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = _imageColor);
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('packages/game_kit/IBMPlexSansKR');
    font.addFont(
      rootBundle.load('packages/game_kit/assets/fonts/IBMPlexSansKR-Bold.ttf'),
    );
    await font.load();
  });

  for (final size in [
    const Size(1024, 768),
    const Size(1280, 800),
    const Size(600, 900),
  ]) {
    for (final useImage in [false, true]) {
      testWidgets(
        'table background covers viewport $size image=$useImage before zoom',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pending = Completer<bool>();
          var prepared = 0;
          var completed = 0;
          final key = GlobalKey();
          final image = useImage ? await tester.runAsync(_background) : null;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: useImage
                      ? const EdgeInsets.fromLTRB(16, 24, 16, 34)
                      : EdgeInsets.zero,
                ),
                child: RepaintBoundary(
                  key: key,
                  child: PlayerLayoutEditor(
                    initialLayout: _layout,
                    tableColor: _gameColor,
                    tableBackgroundImage: image,
                    onPrepare: (_) {
                      prepared++;
                      return pending.future;
                    },
                    onComplete: (_) => completed++,
                    onCancel: () async => true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _expectEdges(tester, key, MosiSeatTheme.fallback.ground);
          if (image != null) {
            await tester.runAsync(
              () => precacheImage(
                image,
                tester.element(find.byType(PlayerLayoutEditor)),
              ),
            );
          }
          await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
          await tester.pump();
          expect(
            prepared,
            1,
            reason: 'Server preparation starts with the entrance animation',
          );
          await tester.pump(const Duration(milliseconds: 1000));
          await _expectEdges(tester, key, useImage ? _imageColor : _gameColor);
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump(const Duration(milliseconds: 300));
          expect(prepared, 1);
          expect(completed, 0);
          await _expectEdges(tester, key, useImage ? _imageColor : _gameColor);
          // Failed preparation reverses the same full-screen reveal cleanly.
          pending.complete(false);
          await tester.pumpAndSettle();
          await _expectEdges(tester, key, MosiSeatTheme.fallback.ground);
          expect(completed, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('zoom hands off once with no background strip', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<bool>();
    var completed = 0;
    var prepared = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: PlayerLayoutEditor(
            initialLayout: _layout,
            tableColor: _gameColor,
            onPrepare: (_) {
              prepared++;
              return pending.future;
            },
            onComplete: (_) => completed++,
            onCancel: () async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
    await tester.pump();
    expect(prepared, 1);
    pending.complete(true);
    await tester.pump();
    expect(completed, 0, reason: 'Fast response cannot skip the entrance/zoom');
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(completed, 1);
    await _expectEdges(tester, key, _gameColor);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
