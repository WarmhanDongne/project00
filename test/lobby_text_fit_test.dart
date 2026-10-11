import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/generated/l10n/app_localizations.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/store/screens/tablet_store_screen.dart';
import 'package:project00/platform/home/tablet/screens/tablet_game_detail.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_layout.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';

// 실제 글꼴로 그려야 글자 폭·높이가 기기와 같아집니다.
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

// 실제 목록처럼 소개·인원·시간을 채웁니다. 파이널콜은 4명·6명만 시작할 수
// 있어 선반 아래 소개에 시작 인원 안내까지 붙는 가장 긴 경우입니다.
final _games = [
  GameInfo.fromJson({
    'id': 'liars_poker',
    'name': '라이어스 포커',
    'description': '카드를 내고, 거짓말이다 싶으면 LIAR를 외치세요.',
    'minPlayers': 2,
    'maxPlayers': 6,
    'playTime': 15,
    'storeVisible': true,
  }),
  GameInfo.fromJson({
    'id': 'mafia',
    'name': '마피아',
    'description': '밤에는 몰래 능력을 쓰고 낮에는 토론으로 마피아를 찾아요.',
    'minPlayers': 4,
    'maxPlayers': 12,
    'playTime': 30,
    'storeVisible': true,
  }),
  GameInfo.fromJson({
    'id': 'final_call',
    'name': '파이널콜',
    'description':
        '같은 색 합이나 같은 숫자 합으로 점수를 겨루는 팀전 카드 게임이에요. '
        '이길 것 같으면 CALL을 외쳐 판을 끝내세요.',
    'minPlayers': 4,
    'maxPlayers': 6,
    'playTime': 20,
    'storeVisible': true,
  }),
  GameInfo.fromJson({
    'id': 'holdem',
    'name': '텍사스 홀덤',
    'description': '내 카드 2장과 공용 카드 5장으로 가장 강한 패를 만들어요.',
    'minPlayers': 2,
    'maxPlayers': 8,
    'playTime': 30,
    'storeVisible': true,
  }),
];

const _players = [
  RoomPlayer(
    uid: 'a',
    nickname: '사라',
    characterId: 'frog',
    seatIndex: 0,
    isConnected: true,
    role: 'player',
    status: 'active',
    penaltyAttemptCount: 0,
  ),
  RoomPlayer(
    uid: 'b',
    nickname: '민준',
    characterId: 'bear',
    seatIndex: 1,
    isConnected: true,
    role: 'player',
    status: 'active',
    penaltyAttemptCount: 0,
  ),
];

// 자주 쓰는 iPad·안드로이드 태블릿의 가로·세로 크기입니다.
const _sizes = [
  Size(1024, 768),
  Size(1133, 744),
  Size(1180, 820),
  Size(1194, 834),
  Size(1280, 800),
  Size(960, 600),
  Size(768, 1024),
];

Rect _global(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// 완전히 투명하게 숨겨 둔 글자(나타나기 전 꼬리표 등)는 보이지 않으니 건너뜁니다.
bool _invisible(RenderObject render) {
  for (RenderObject? node = render; node != null; node = node.parent) {
    if (node is RenderOpacity && node.opacity == 0) return true;
    if (node is RenderAnimatedOpacity && node.opacity.value == 0) return true;
  }
  return false;
}

/// 말줄임표로 잘렸거나 자르는 부모·화면 밖으로 빠져나간 글자를 모읍니다.
List<String> _clippedTexts(WidgetTester tester) {
  final screen = Offset.zero & tester.view.physicalSize;
  final clipped = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.hasSize) continue;
    final text = render.text.toPlainText();
    if (text.trim().isEmpty || _invisible(render)) continue;
    if (render.didExceedMaxLines ||
        render.getMinIntrinsicHeight(render.size.width) >
            render.size.height + 1) {
      clipped.add(text);
      continue;
    }
    final rect = _global(render);
    var bounds = screen;
    for (RenderObject? node = render.parent; node != null; node = node.parent) {
      final clips =
          node is RenderClipRect ||
          node is RenderClipRRect ||
          node is RenderClipPath ||
          (node is RenderStack && node.clipBehavior != Clip.none);
      if (clips && (node as RenderBox).hasSize) {
        bounds = bounds.intersect(_global(node));
      }
    }
    final visible = bounds.intersect(rect);
    if (visible.width < rect.width - 1.5 ||
        visible.height < rect.height - 1.5) {
      clipped.add(text);
    }
  }
  return clipped;
}

Widget _app(Locale locale, Widget home) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

_RoomProvider _room() => _RoomProvider()
  ..roomCode = 'ABCDE'
  ..players = _players
  ..groupGames = _games
  ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;

Future<void> _settle(WidgetTester tester) async {
  // 반복 연출이 있어 pumpAndSettle 대신 등장 연출이 끝날 만큼 넘깁니다.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // 기기 설정에서 글자 크기를 키운 경우(1.3배)도 함께 봅니다.
  for (final (locale, textScale) in const [
    (Locale('ko'), 1.0),
    (Locale('en'), 1.0),
    (Locale('ko'), 1.3),
  ]) {
    testWidgets('${locale.languageCode} ×$textScale 상점·선반·게임 상세의 글자가 태블릿 크기에서 '
        '잘리거나 스크롤 없이 보인다', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final problems = <String>[];
      final games = GameProvider(service: _GameService())..games = _games;
      addTearDown(games.dispose);
      for (final size in _sizes) {
        tester.view.physicalSize = size;

        await tester.pumpWidget(
          _app(locale, TabletStoreScreen(gameProvider: games)),
        );
        await _settle(tester);
        for (final name in [..._games.map((game) => game.id), 'soon']) {
          await tester.tap(
            find.byKey(ValueKey('store-book-$name')),
            warnIfMissed: false,
          );
          await _settle(tester);
          for (final text in _clippedTexts(tester)) {
            problems.add('상점 $size $name: $text');
          }
          if (tester.takeException() case final Object error) {
            problems.add('상점 $size $name: $error');
          }
        }

        for (final game in _games) {
          final room = _room();
          await tester.pumpWidget(
            _app(
              locale,
              Scaffold(
                body: TabletLobbyLayout(
                  header: const SizedBox(height: 48),
                  content: TabletGameShelf(
                    gameProvider: games,
                    roomProvider: room,
                    selectedGameId: game.id,
                    onSelect: (_) {},
                    onOpenDetail: (_) {},
                    theme: MosiGameArt.of(game.id).shelfTheme,
                    onlyPlayable: false,
                    onOnlyPlayableChanged: (_) {},
                  ),
                  roomPanel: TabletRoomPanel(provider: room, onStart: () {}),
                ),
              ),
            ),
          );
          await _settle(tester);
          final where = '선반 $size ${game.id}';
          for (final text in _clippedTexts(tester)) {
            problems.add('$where: $text');
          }
          if (tester.takeException() case final Object error) {
            problems.add('$where: $error');
          }
          // 선반 아래 소개는 스크롤 없이 한 번에 보여야 합니다.
          final content = find.byType(TabletGameShelf);
          if (find
              .descendant(of: content, matching: find.byType(Scrollable))
              .evaluate()
              .isNotEmpty) {
            problems.add('$where: 소개가 스크롤 안에 있음');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          room.dispose();
        }

        for (final game in _games) {
          for (final parts in [false, true]) {
            final room = _room();
            await tester.pumpWidget(
              _app(
                locale,
                Scaffold(
                  body: TabletLobbyLayout(
                    header: const SizedBox(height: 48),
                    content: TabletGameDetailContent(
                      game: game,
                      roomProvider: room,
                    ),
                    roomPanel: TabletRoomPanel(provider: room, onStart: () {}),
                  ),
                ),
              ),
            );
            await tester.pump();
            if (parts) {
              await tester.tap(find.text('구성품'), warnIfMissed: false);
            }
            await _settle(tester);
            final where = '상세 $size ${game.id} ${parts ? '구성품' : '미리보기'}';
            for (final text in _clippedTexts(tester)) {
              problems.add('$where: $text');
            }
            if (tester.takeException() case final Object error) {
              problems.add('$where: $error');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            room.dispose();
          }
        }
      }
      expect(problems, isEmpty);
    });
  }
}

class _RoomProvider extends RoomProvider {
  _RoomProvider()
    : super(
        service: _RoomService(),
        gameService: _GameService(),
        gameCatalog: _Catalog(),
      );
}

class _RoomService implements RoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GameService implements GameService {
  @override
  Future<List<GameInfo>> fetchGames() async => _games;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements GameCatalog {
  @override
  Iterable<TemplateGame> get games => const [];
  @override
  TemplateGame? find(String id) => null;
}
