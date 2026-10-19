import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:game_yut/game_yut.dart';
import 'package:game_yut/game_sounds.dart';
import 'package:game_yut/src/rules.dart';
import 'package:game_yut/src/view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Yut background music is bundled as a game asset', () async {
    final music = await rootBundle.load(YutSounds.background);
    expect(music.lengthInBytes, greaterThan(0));
  });

  test('the tablet throw sound is bundled as a game asset', () async {
    final sound = await rootBundle.load(YutSounds.throwSticks);
    expect(sound.lengthInBytes, greaterThan(0));
  });

  test(
    'classic Yut uses its catalog range; strategy variants stay four-player',
    () {
      expect(const YutGame().supportedPlayerCounts, isNull);
      expect(const StrategyYutGame().supportedPlayerCounts, [4]);
      expect(const StrategyYutEditionGame().supportedPlayerCounts, [4]);
    },
  );

  group('YutBoard.advance mirrors the server board', () {
    test('outer ring passes the start corner and goes home', () {
      expect(YutBoard.advance([], 1), [1]);
      final ring = List.generate(19, (i) => i + 1);
      expect(YutBoard.advance(ring, 1).last, 0);
      expect(YutBoard.advance([...ring, 0], 1).last, YutBoard.home);
    });

    test('corners start the diagonal and the centre heads home', () {
      expect(YutBoard.advance([1, 2, 3, 4, 5], 3).sublist(5), [20, 21, 22]);
      expect(YutBoard.advance([1, 2, 3, 4, 5, 20, 21], 3).sublist(7), [
        22,
        23,
        24,
      ]);
      expect(YutBoard.advance([1, 2, 3, 4, 5, 20, 21, 22], 2).sublist(8), [
        27,
        28,
      ]);
      final ten = List.generate(10, (i) => i + 1);
      expect(YutBoard.advance(ten, 5).sublist(10), [25, 26, 22, 27, 28]);
    });

    test('back-do retraces one step', () {
      expect(YutBoard.advance([1, 2, 3], -1), [1, 2]);
      expect(YutBoard.advance([1], -1), [0]);
      expect(YutBoard.advance([0], -1), [19]);
    });

    test('nodes form the 29-point board with the start at bottom right', () {
      final nodes = YutBoard.nodes(lo: .1, hi: .9);
      expect(nodes, hasLength(YutBoard.nodeCount));
      expect(nodes[0], const Offset(.9, .9));
      expect(nodes[5], const Offset(.9, .1));
      expect(nodes[10], const Offset(.1, .1));
      expect(nodes[15], const Offset(.1, .9));
      expect(nodes[22], const Offset(.5, .5));
    });
  });

  test('public state without empty arrays still parses', () {
    final view = YutGameView.fromPublic('strategy_yut', {
      'status': 'playing',
      'phase': 'moving',
      'turnTeam': 'blue',
      'turnUid': 'a',
      'players': {
        'a': {'nickname': '지민', 'seatIndex': 0, 'team': 'blue'},
        'c': {'nickname': '서준', 'seatIndex': 2, 'team': 'blue'},
      },
      'pieces': {
        'blue': [
          {
            'id': 0,
            'position': 3,
            'path': [1, 2, 3],
            'status': 'onBoard',
          },
          {'id': 3, 'position': -1, 'status': 'ready'},
        ],
      },
      'pool': [
        {'name': 'yut', 'steps': 4},
        {'name': 'geol', 'steps': 3},
      ],
    });
    expect(view.pool.map((chip) => chip.result), [
      YutResult.yut,
      YutResult.geol,
    ]);
    expect(view.piecesOf('blue').last.path, isEmpty);
    expect(view.pieceKeeper('blue', 0)?.nickname, '지민');
    expect(view.pieceKeeper('blue', 3)?.nickname, '서준');
  });
}
