import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// 앱과 같은 기본 글꼴입니다. 글꼴을 지정하지 않은 글자도 기기처럼 그립니다.
ThemeData sweepTheme() => ThemeData(
  fontFamily: MosiFonts.bodyFamily(const Locale('ko')),
  fontFamilyFallback: MosiFonts.fallbacks(const Locale('ko')),
);

/// 화면 크기와 안전 영역(노치·홈 막대)을 함께 담은 기기입니다.
class SweepDevice {
  const SweepDevice(this.name, this.size, {this.padding = EdgeInsets.zero});

  final String name;
  final Size size;
  final EdgeInsets padding;

  SweepDevice get landscape => SweepDevice(
    '$name 가로',
    Size(size.height, size.width),
    padding: padding == EdgeInsets.zero
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(padding.top, 0, padding.top, padding.bottom / 2),
  );

  @override
  String toString() =>
      '$name ${size.width.toInt()}×${size.height.toInt()}';
}

/// 작은 SE부터 큰 Pro Max·안드로이드까지 세로 휴대폰입니다.
const sweepPhones = [
  SweepDevice('iPhone SE 1', Size(320, 568)),
  SweepDevice('작은 안드로이드', Size(360, 640)),
  SweepDevice('Galaxy S', Size(360, 780), padding: EdgeInsets.only(top: 24)),
  SweepDevice('iPhone SE 3', Size(375, 667), padding: EdgeInsets.only(top: 20)),
  SweepDevice('iPhone 13 mini', Size(375, 812), padding: EdgeInsets.only(top: 50, bottom: 34)),
  SweepDevice('iPhone 14', Size(390, 844), padding: EdgeInsets.only(top: 47, bottom: 34)),
  SweepDevice('Pixel 7', Size(412, 915), padding: EdgeInsets.only(top: 24)),
  SweepDevice('iPhone Pro Max', Size(430, 932), padding: EdgeInsets.only(top: 59, bottom: 34)),
];

/// 태블릿 게임은 가로로만 씁니다.
const sweepTablets = [
  SweepDevice('작은 안드로이드 탭', Size(960, 600), padding: EdgeInsets.only(top: 24)),
  SweepDevice('iPad 9', Size(1080, 810), padding: EdgeInsets.only(top: 20)),
  SweepDevice('iPad mini', Size(1133, 744), padding: EdgeInsets.only(top: 24, bottom: 20)),
  SweepDevice('iPad Air', Size(1180, 820), padding: EdgeInsets.only(top: 24, bottom: 20)),
  SweepDevice('iPad Pro 11', Size(1194, 834), padding: EdgeInsets.only(top: 24, bottom: 20)),
  SweepDevice('Galaxy Tab', Size(1280, 800), padding: EdgeInsets.only(top: 24)),
  SweepDevice('iPad Pro 13', Size(1366, 1024), padding: EdgeInsets.only(top: 24, bottom: 20)),
  SweepDevice('큰 안드로이드 탭', Size(1920, 1200), padding: EdgeInsets.only(top: 24)),
  SweepDevice('iPad 1024', Size(1024, 768), padding: EdgeInsets.only(top: 20)),
];

List<SweepDevice> get sweepPhonesLandscape =>
    [for (final device in sweepPhones) device.landscape];

/// 실제 글꼴로 그려야 글자 폭·높이가 기기와 같아집니다.
///
/// 패키지 테스트에는 앱(루트 pubspec)이 선언한 글꼴(Rye·Caprasimo 등)이 없어
/// 네모 글자로 그려지므로, 루트 pubspec의 글꼴 파일도 직접 읽어 등록합니다.
Future<void> loadSweepFonts(WidgetTester tester) => tester.runAsync(() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final rootPubspec = File('../../pubspec.yaml');
  if (!rootPubspec.existsSync()) return;
  String? family;
  final files = <String, List<String>>{};
  var inFonts = false;
  for (final line in rootPubspec.readAsLinesSync()) {
    if (line.startsWith('  fonts:')) {
      inFonts = true;
      continue;
    }
    if (!inFonts) continue;
    if (line.isNotEmpty && !line.startsWith('   ')) break;
    final familyMatch = RegExp(r'- family:\s*(\S+)').firstMatch(line);
    if (familyMatch != null) family = familyMatch.group(1);
    final assetMatch = RegExp(r'- asset:\s*(\S+)').firstMatch(line);
    if (assetMatch != null && family != null) {
      files.putIfAbsent(family, () => []).add(assetMatch.group(1)!);
    }
  }
  for (final MapEntry(key: name, value: paths) in files.entries) {
    final loader = FontLoader(name);
    for (final path in paths) {
      final file = File('../../$path');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
});

void applySweepDevice(WidgetTester tester, SweepDevice device) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = device.size * 3;
  final padding = FakeViewPadding(
    left: device.padding.left * 3,
    top: device.padding.top * 3,
    right: device.padding.right * 3,
    bottom: device.padding.bottom * 3,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
}

/// 넘침 오류와 잘린 글자를 모읍니다.
class OverflowSweep {
  final problems = <String>{};
  void Function(FlutterErrorDetails)? _previous;
  String where = '';

  void start() {
    _previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString().split('\n').first;
      final at = details
          .toString()
          .split('\n')
          .firstWhere((line) => line.contains('.dart:'), orElse: () => '')
          .replaceAll(RegExp(r'file:///\S*/(packages|lib)/'), '')
          .trim();
      problems.add('$where | $message | $at');
    };
  }

  void stop() {
    FlutterError.onError = _previous;
    // 목록이 길면 실패 메시지가 잘리므로 SWEEP_OUT이 있으면 전부 파일로 남깁니다.
    final out = Platform.environment['SWEEP_OUT'];
    if (out != null && problems.isNotEmpty) {
      File(out).writeAsStringSync(
        '${(problems.toList()..sort()).join('\n')}\n',
        mode: FileMode.append,
      );
    }
  }

  /// SWEEP_SHOT 폴더가 있으면 지금 화면을 PNG로 남깁니다(사람 눈 확인용).
  Future<void> shot(WidgetTester tester, String name) async {
    final dir = Platform.environment['SWEEP_SHOT'];
    if (dir == null) return;
    final match = Platform.environment['SWEEP_SHOT_MATCH'];
    if (match != null && !where.contains(match)) return;
    final boundaries = find.byType(RepaintBoundary);
    if (boundaries.evaluate().isEmpty) return;
    final render = tester.renderObject(boundaries.first);
    if (render is! RenderRepaintBoundary) return;
    final boundary = render;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/${name.replaceAll(RegExp(r'[^0-9A-Za-z가-힣×]+'), '_')}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// 말줄임표로 잘렸거나 잘라 내는 부모·화면 밖으로 빠진 글자를 찾습니다.
  void scanText(WidgetTester tester) {
    final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    for (final element in find.byType(RichText).evaluate()) {
      final render = element.renderObject;
      if (render is! RenderParagraph || !render.hasSize || !render.attached) continue;
      final text = render.text.toPlainText().replaceAll('\n', ' ');
      if (text.trim().isEmpty || _invisible(render)) continue;
      final short = text.length > 30 ? '${text.substring(0, 30)}…' : text;
      if (render.didExceedMaxLines) {
        problems.add('$where | 말줄임 | "$short"');
        continue;
      }
      if (render.getMinIntrinsicHeight(render.size.width) > render.size.height + 1) {
        problems.add('$where | 글자 높이 잘림 | "$short"');
        continue;
      }
      final rect = MatrixUtils.transformRect(
        render.getTransformTo(null),
        Offset.zero & render.size,
      );
      if (rect.isEmpty) continue;
      // 스크롤 목록 안의 글자는 가장자리에서 가려지는 것이 정상이라 넘침·말줄임만 봅니다.
      if (_insideScroll(render)) continue;
      var bounds = screen;
      var cutBy = '화면';
      for (RenderObject? node = render.parent; node != null; node = node.parent) {
        final clips = node is RenderClipRect ||
            node is RenderClipRRect ||
            node is RenderClipPath ||
            (node is RenderStack && node.clipBehavior != Clip.none);
        if (clips && node is RenderBox && node.hasSize) {
          final next = bounds.intersect(MatrixUtils.transformRect(
            node.getTransformTo(null),
            Offset.zero & node.size,
          ));
          if (next != bounds) cutBy = node.runtimeType.toString();
          bounds = next;
        }
      }
      final visible = bounds.intersect(rect);
      // 완전히 화면 밖·가려진 글자는 연출 중일 수 있어 건너뜁니다.
      if (visible.width <= 0 || visible.height <= 0) continue;
      if (visible.width < rect.width - 1.5 || visible.height < rect.height - 1.5) {
        problems.add('$where | 글자 일부 잘림($cutBy) | "$short"');
      }
    }
  }

  static bool _insideScroll(RenderObject render) {
    for (RenderObject? node = render.parent; node != null; node = node.parent) {
      if (node is RenderAbstractViewport) return true;
    }
    return false;
  }

  static bool _invisible(RenderObject render) {
    for (RenderObject? node = render; node != null; node = node.parent) {
      if (node is RenderOpacity && node.opacity < .05) return true;
      if (node is RenderAnimatedOpacity && node.opacity.value < .05) return true;
      if (node is RenderOffstage && node.offstage) return true;
    }
    return false;
  }
}
