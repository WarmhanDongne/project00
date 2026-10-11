import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_book_carousel.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_content_transition.dart';

final _books = [
  GameInfo.fromJson({'id': 'liars_poker', 'name': '라이어스 포커'}),
  GameInfo.fromJson({'id': 'final_call', 'name': '파이널콜'}),
  GameInfo.fromJson({'id': 'mafia', 'name': '마피아'}),
];

void main() {
  test('선택 가능한 캐릭터는 이전 서버의 ID를 유지하며 새 그림 파일이 존재한다', () {
    // 리디자인 이전에 배포된 room character 계약. 새 그림 이름을 보내면 안 됩니다.
    const serverIds = {
      'bear',
      'bee',
      'cat',
      'crab',
      'deer',
      'elephant',
      'frog',
      'giraffe',
      'hedgehog',
      'kindbear',
      'octopus',
      'owl',
      'penguin',
      'rabbit',
      'shark',
      'snake',
      'whale',
    };
    expect(roomCharacters.map((c) => c.id).toSet(), serverIds);
    expect(
      roomCharacters.map((c) => c.assetPath).toSet().length,
      serverIds.length,
    );
    for (final character in roomCharacters) {
      expect(
        File(character.assetPath).existsSync(),
        isTrue,
        reason: character.id,
      );
      final artId = character.assetPath
          .split('/')
          .last
          .replaceFirst('.webp', '');
      expect(roomCharacterById(artId).id, character.id);
      expect(roomCharacterAssetPath(artId), character.assetPath);
    }
    expect(defaultRoomCharacterId, 'frog');
    expect(roomCharacterById('burger').id, roomCharacterById('frog').id);
    for (final id in ['cone', 'catcher', 'bandage']) {
      expect(roomCharacterAssetPath(id), endsWith('/$id.webp'));
      expect(roomCharacters.any((character) => character.id == id), isFalse);
    }
  });

  testWidgets('느린 양방향 스와이프·고정 순서·양 끝 경계·옆 책 클릭·상세를 지원한다', (tester) async {
    var selected = _books.first;
    GameInfo? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 620,
                child: TabletBookCarousel(
                  games: _books,
                  selected: selected,
                  coverWidth: 200,
                  deep: Colors.black,
                  onSelect: (game) => setState(() => selected = game),
                  onOpenDetail: (game) => opened = game,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final carousel = find.byKey(const Key('book-carousel'));
    final selectedRect = tester.getRect(
      find.byKey(const Key('shelf-selected-cover')),
    );
    expect(selectedRect.width, 200);
    expect(selectedRect.height, 288);
    final nextRect = tester.getRect(
      find.byKey(const ValueKey('shelf-spine-final_call')),
    );
    expect(nextRect.left - selectedRect.right, closeTo(24, .01));
    expect(nextRect.width, 46);
    expect(nextRect.height, 288);
    expect(
      tester.getRect(find.byKey(const ValueKey('shelf-spine-mafia'))).left,
      greaterThan(nextRect.right),
    );

    Future<void> slowlySwipe(double dx) async {
      final gesture = await tester.startGesture(tester.getCenter(carousel));
      await gesture.moveBy(Offset(dx / 2, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(Offset(dx / 2, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await slowlySwipe(-80);
    expect(selected.id, 'final_call');
    expect(opened, isNull);
    await slowlySwipe(80);
    expect(selected.id, 'liars_poker');
    await slowlySwipe(80);
    expect(selected.id, 'liars_poker');
    await slowlySwipe(-80);
    await slowlySwipe(-80);
    expect(selected.id, 'mafia');
    await slowlySwipe(-80);
    expect(selected.id, 'mafia');
    await tester.tap(find.byKey(const ValueKey('shelf-spine-final_call')));
    await tester.pumpAndSettle();
    expect(selected.id, 'final_call');
    await tester.tap(find.byKey(const Key('shelf-selected-cover')));
    expect(opened?.id, 'final_call');
    expect(tester.takeException(), isNull);
  });

  testWidgets('책을 교체해도 같은 애니메이션 State에서 회전 중간 프레임을 그린다', (tester) async {
    var selected = _books.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 620,
                child: TabletBookCarousel(
                  games: _books,
                  selected: selected,
                  coverWidth: 200,
                  deep: Colors.black,
                  onSelect: (game) => setState(() => selected = game),
                  onOpenDetail: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final animation = find.byType(TweenAnimationBuilder<double>);
    final originalState = tester.state(animation);
    await tester.tap(find.byKey(const ValueKey('shelf-spine-final_call')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.state(animation), same(originalState));
    final transform = tester
        .widget<Transform>(
          find.byKey(const ValueKey('book-front-turn-final_call')),
        )
        .transform;
    expect(
      tester
          .getRect(find.byKey(const ValueKey('book-front-turn-final_call')))
          .height,
      closeTo(288, 0.01),
    );
    expect(transform.entry(0, 0), greaterThan(0.1));
    expect(transform.entry(0, 0), lessThan(0.99));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('book-front-turn-final_call')),
          )
          .transform
          .entry(0, 0),
      closeTo(1, 0.001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('홀덤은 전용 카드 박스 표지를 쓰고 일반 책보다 작게 표시한다', (tester) async {
    final holdem = GameInfo.fromJson({'id': 'holdem', 'name': '홀덤'});
    final books = [_books.first, holdem];
    var selected = books.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 620,
                child: TabletBookCarousel(
                  games: books,
                  selected: selected,
                  coverWidth: 200,
                  deep: Colors.black,
                  onSelect: (game) => setState(() => selected = game),
                  onOpenDetail: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final regular = tester.getRect(
      find.byKey(const Key('shelf-selected-cover')),
    );
    await tester.tap(find.byKey(const ValueKey('shelf-spine-holdem')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(
          'packages/game_kit/assets/images/covers/poker_cardbox.png',
        ),
        tester.element(find.byKey(const Key('holdem-cardbox-cover'))),
      );
    });
    await tester.pump();

    final smaller = tester.getRect(
      find.byKey(const Key('shelf-selected-cover')),
    );
    expect(smaller.width, closeTo(regular.width * 0.88, 0.01));
    expect(smaller.height, closeTo(regular.height * 0.88, 0.01));
    expect(find.byKey(const Key('holdem-cardbox-cover')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final count in [1, 2, 4, 8]) {
    testWidgets('책 $count권에서도 선택 이동과 반복 입력이 유효하다', (tester) async {
      final books = List.generate(
        count,
        (index) => index < _books.length
            ? _books[index]
            : GameInfo.fromJson({'id': 'game$index', 'name': '게임 $index'}),
      );
      var selected = books.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Center(
                child: SizedBox(
                  width: 700,
                  child: TabletBookCarousel(
                    games: books,
                    selected: selected,
                    coverWidth: 200,
                    deep: Colors.black,
                    onSelect: (game) => setState(() => selected = game),
                    onOpenDetail: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final carousel = find.byKey(const Key('book-carousel'));
      await tester.drag(carousel, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(selected.id, books[count == 1 ? 0 : 1].id);
      if (count == 2) {
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('shelf-spine-liars_poker')))
              .dx,
          lessThan(
            tester.getCenter(find.byKey(const Key('shelf-selected-cover'))).dx,
          ),
        );
      }
      // 애니메이션 도중 다시 밀어도 마지막 선택으로 수렴합니다.
      await tester.drag(carousel, const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.drag(carousel, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(selected.id, books[count <= 2 ? 0 : 1].id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('방이 없어도 이전 인원 필터에 가려지지 않고 책 클릭·상세가 동작한다', (tester) async {
    final provider = RoomProvider(
      service: _RoomService(),
      gameService: _GameService(),
    );
    final games = GameProvider(service: _GameService())..games = _books;
    addTearDown(provider.dispose);
    addTearDown(games.dispose);
    var selected = _books.first;
    GameInfo? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 700,
              height: 600,
              child: TabletGameShelf(
                gameProvider: games,
                roomProvider: provider,
                selectedGameId: selected.id,
                onSelect: (game) => setState(() => selected = game),
                onOpenDetail: (game) => opened = game,
                theme: MosiGameArt.liarsPoker.shelfTheme,
                onlyPlayable: true,
                onOnlyPlayableChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(MosiEmptySpine), findsNWidgets(5));
    await tester.tap(find.byKey(const ValueKey('shelf-spine-final_call')));
    await tester.pumpAndSettle();
    expect(selected.id, 'final_call');
    await tester.tap(find.text('자세히 보기'));
    expect(opened?.id, 'final_call');
    expect(provider.roomCode, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('상세 전환에서 이전 책장이 왼쪽으로 빠지며 퇴장 요소 클릭은 차단한다', (tester) async {
    var detail = false;
    var oldTaps = 0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return SizedBox(
                width: 600,
                height: 500,
                child: TabletLobbyContentTransition(
                  child: detail
                      ? const ColoredBox(
                          key: ValueKey('lobby-detail-game'),
                          color: Colors.white,
                        )
                      : GestureDetector(
                          key: const ValueKey('lobby-shelf'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => oldTaps++,
                          child: const ColoredBox(color: Colors.blue),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final oldRect = tester.getRect(find.byKey(const ValueKey('lobby-shelf')));
    change(() => detail = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(
      tester.getRect(find.byKey(const ValueKey('lobby-shelf'))).left,
      lessThan(oldRect.left),
    );
    await tester.tapAt(oldRect.center);
    expect(oldTaps, 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lobby-shelf')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('준비 표시와 LP 배경 대기에서도 선택한 책 자리를 잴 수 있다', (tester) async {
    final coverKey = GlobalKey();
    Widget carousel({required bool preparing, GameInfo? selected}) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 620,
                child: TabletBookCarousel(
                  games: _books,
                  selected: selected ?? _books[1],
                  coverWidth: 200,
                  deep: Colors.black,
                  onSelect: (_) {},
                  onOpenDetail: (_) {},
                  preparing: preparing,
                  selectedCoverKey: coverKey,
                ),
              ),
            ),
          ),
        );
    double badgeOpacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byKey(const Key('shelf-preparing-badge')),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    await tester.pumpWidget(carousel(preparing: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shelf-preparing-badge')), findsNothing);
    expect(coverKey.currentContext, isNotNull);

    await tester.pumpWidget(carousel(preparing: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(badgeOpacity(), 1);
    final cover = tester.getRect(find.byKey(coverKey));
    expect(cover.width, greaterThan(0));
    expect(cover.height, greaterThan(0));

    await tester.pumpWidget(carousel(preparing: true, selected: _books.first));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shelf-preparing-badge')), findsNothing);
    // Other books retain their transparent badges for the fade transition.
    expect(find.text('게임 준비 중').hitTestable(), findsNothing);
    final lpCover = tester.getRect(find.byKey(coverKey));
    expect(lpCover.width, greaterThan(0));
    expect(lpCover.height, greaterThan(0));
  });
}

class _RoomService implements RoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
