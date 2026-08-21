import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_session_provider.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/liars_poker/services/liars_poker_command_service.dart';
import 'package:project00/games/liars_poker/services/liars_poker_query_service.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================휴대폰 회전 재현==============================
// 실기기에서 보고된 버그: 2인 게임 진행 중 휴대폰을 가로로 돌리면 터졌습니다.
//
// 실제 컨트롤러를 가짜 서비스로 띄우고, 진행 중 상태에서 화면 크기를
// 세로 → 가로 → 세로로 바꿔 회전을 그대로 재현합니다. 예외와 레이아웃
// 오버플로는 테스트에서 자동으로 실패가 됩니다.

/// RTDB 스냅샷 흉내입니다. 컨트롤러는 `value`만 읽습니다.
class _FakeSnapshot implements DataSnapshot {
  _FakeSnapshot(this._value);
  final Object? _value;

  @override
  Object? get value => _value;

  @override
  bool get exists => _value != null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeEvent implements DatabaseEvent {
  _FakeEvent(Object? value) : snapshot = _FakeSnapshot(value);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Firebase 없이 스트림만 흘려 주는 읽기 서비스입니다.
class _FakeQuery implements LiarsPokerQueryService {
  final publicGame = StreamController<DatabaseEvent>.broadcast();
  final privateHand = StreamController<DatabaseEvent>.broadcast();

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => publicGame.stream;

  @override
  Stream<DatabaseEvent> watchPrivateHand({
    required String roomCode,
    required String uid,
  }) => privateHand.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 서버 명령을 삼키는 쓰기 서비스입니다. 예열 호출만 조용히 받습니다.
class _FakeCommand implements LiarsPokerCommandService {
  @override
  Future<Map<String, dynamic>> warmUpGameplayCommands() async => const {};

  @override
  Future<Map<String, dynamic>> warmUpLiarCommand() async => const {};

  @override
  Future<Map<String, dynamic>> readyTurn({required String roomCode}) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeInterruption implements GameInterruptionCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 2인 진행 중 공개 상태입니다. 내(u1) 차례이고 아직 아무도 내지 않았습니다.
Map<String, Object?> publicState() => {
  'status': 'playing',
  'phase': 'playing',
  'table': 'K',
  'turnUid': 'u1',
  'round': 1,
  'revision': 3,
  'players': {
    'u1': {
      'uid': 'u1',
      'nickname': '플레이어1',
      'characterId': 'frog',
      'status': 'alive',
      'remainingCardCount': 5,
      'seatIndex': 0,
    },
    'u2': {
      'uid': 'u2',
      'nickname': '플레이어2',
      'characterId': 'rabbit',
      'status': 'alive',
      'remainingCardCount': 5,
      'seatIndex': 1,
    },
  },
};

Map<String, Object?> privateHand() => {
  'hand': {
    'c1': {'id': 'c1', 'rank': 'K'},
    'c2': {'id': 'c2', 'rank': 'K'},
    'c3': {'id': 'c3', 'rank': 'Q'},
    'c4': {'id': 'c4', 'rank': 'A'},
    'c5': {'id': 'c5', 'rank': 'JOKER'},
  },
};

void main() {
  /// 실제 컨트롤러를 가짜 서비스로 띄우고 화면을 세로로 펌프합니다.
  Future<(LiarsPokerController, _FakeQuery)> pumpPortrait(
    WidgetTester tester,
  ) async {
    final query = _FakeQuery();
    final service = LiarsPokerService(
      command: _FakeCommand(),
      query: query,
      interruption: _FakeInterruption(),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = liarsPokerSessionProvider(
      LiarsPokerSessionArgs(
        roomCode: 'TESTR',
        uid: 'u1',
        service: service,
        watchPrivateHand: true,
      ),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    addTearDown(() {
      unawaited(query.publicGame.close());
      unawaited(query.privateHand.close());
    });

    query.publicGame.add(_FakeEvent(publicState()));
    query.privateHand.add(_FakeEvent(privateHand()));
    await tester.pump();

    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(
          home: LiarsPokerPhoneGameScreen(controller: controller),
        ),
      ),
    );
    return (controller, query);
  }

  /// 가로 → 세로로 되돌리며 매 단계 예외를 확인합니다.
  Future<void> rotateAndBack(WidgetTester tester, {required String at}) async {
    tester.view.physicalSize = const Size(844 * 3, 390 * 3);
    await tester.pump();
    var thrown = tester.takeException();
    expect(thrown, isNull, reason: '[$at] 가로 회전 직후 터졌습니다: $thrown');
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    thrown = tester.takeException();
    expect(thrown, isNull, reason: '[$at] 가로 프레임 진행 중 터졌습니다: $thrown');

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    await tester.pump();
    thrown = tester.takeException();
    expect(thrown, isNull, reason: '[$at] 세로 복귀 직후 터졌습니다: $thrown');
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    thrown = tester.takeException();
    expect(thrown, isNull, reason: '[$at] 세로 복귀 후 터졌습니다: $thrown');
  }

  testWidgets('진행 중(공개 완료) 상태에서 회전해도 터지지 않는다', (tester) async {
    final (controller, _) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull, reason: '세로에서 이미 예외가 있습니다');

    await rotateAndBack(tester, at: '진행 중');
  });

  testWidgets('GAME START 문구가 떠 있는 동안 회전해도 터지지 않는다', (tester) async {
    await pumpPortrait(tester);
    // 문구가 아직 화면에 있는 이른 시점입니다.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await rotateAndBack(tester, at: 'GAME START');
  });

  testWidgets('손패 공개 연출 도중 회전해도 터지지 않는다', (tester) async {
    await pumpPortrait(tester);
    // GAME START가 끝나고 공개 연출(카드 펼치기)이 도는 시점까지만 돌립니다.
    // markHandRevealed를 부르지 않아 연출이 진행 중입니다.
    for (var i = 0; i < 10; i += 1) {
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(tester.takeException(), isNull, reason: '공개 연출 중 세로에서 예외');

    await rotateAndBack(tester, at: '공개 연출 중');
  });

  testWidgets('벌칙(룰렛) 단계에서 회전해도 터지지 않는다', (tester) async {
    final (controller, query) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 2인 게임에서 금방 도달하는 상태입니다. 라이어 선언이 확정되어
    // 벌칙 대상이 정해진 채 룰렛 화면이 떠 있습니다.
    final penalty = publicState()
      ..['phase'] = 'penalty'
      ..['penaltyTargetUid'] = 'u1'
      ..['revision'] = 4
      ..['lastPlay'] = {
        'playId': 'p1',
        'playerUid': 'u2',
        'revealed': true,
        'cardCount': 1,
        'actualRanks': ['Q'],
      };
    query.publicGame.add(_FakeEvent(penalty));
    // 판정 문구(1초 지연 + 2.9초 유지)가 지나가는 동안 몇 프레임 돌립니다.
    for (var i = 0; i < 16; i += 1) {
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(tester.takeException(), isNull, reason: '벌칙 세로에서 이미 예외');

    await rotateAndBack(tester, at: '벌칙 룰렛');
  });

  testWidgets('판정 문구가 떠 있는 동안 회전해도 터지지 않는다', (tester) async {
    final (controller, query) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    final penalty = publicState()
      ..['phase'] = 'penalty'
      ..['penaltyTargetUid'] = 'u1'
      ..['revision'] = 4
      ..['lastPlay'] = {
        'playId': 'p1',
        'playerUid': 'u2',
        'revealed': true,
        'cardCount': 1,
        'actualRanks': ['Q'],
      };
    query.publicGame.add(_FakeEvent(penalty));
    // 판정 문구는 1초 뒤에 떠서 2.9초 유지됩니다. 그 한가운데서 돌립니다.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull, reason: '판정 문구 세로에서 예외');

    await rotateAndBack(tester, at: '판정 문구');
  });

  testWidgets('2라운드 분배 문구 도중 회전해도 터지지 않는다', (tester) async {
    final (controller, query) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 벌칙이 끝나고 2라운드 분배가 시작된 상태입니다. ROUND 문구와 새 손패
    // 공개 연출이 이어집니다.
    final dealing = publicState()
      ..['phase'] = 'dealing'
      ..['round'] = 2
      ..['revision'] = 6;
    query.publicGame.add(_FakeEvent(dealing));
    await tester.pump(const Duration(milliseconds: 300));
    query.privateHand.add(_FakeEvent(privateHand()));
    // ROUND 문구가 떠 있는 도중입니다.
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull, reason: '분배 문구 세로에서 예외');

    await rotateAndBack(tester, at: '2라운드 분배');
  });

  testWidgets('마지막 카드 FOLD 안내 중 회전해도 터지지 않는다', (tester) async {
    final (controller, query) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 상대가 마지막 카드를 냈고 나만 카드가 남아 FOLD를 고를 수 있는 상태입니다.
    final challenge = publicState()
      ..['phase'] = 'lastCardChallenge'
      ..['turnUid'] = 'u1'
      ..['revision'] = 5
      ..['players'] = {
        'u1': {
          'uid': 'u1',
          'nickname': '플레이어1',
          'characterId': 'frog',
          'status': 'alive',
          'remainingCardCount': 5,
          'seatIndex': 0,
        },
        'u2': {
          'uid': 'u2',
          'nickname': '플레이어2',
          'characterId': 'rabbit',
          'status': 'alive',
          'remainingCardCount': 0,
          'seatIndex': 1,
        },
      }
      ..['lastPlay'] = {
        'playId': 'p9',
        'playerUid': 'u2',
        'revealed': false,
        'cardCount': 1,
      };
    query.publicGame.add(_FakeEvent(challenge));
    for (var i = 0; i < 4; i += 1) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull, reason: 'FOLD 세로에서 예외');

    await rotateAndBack(tester, at: 'FOLD 안내');
  });

  testWidgets('카드를 선택한 상태로 회전해도 터지지 않는다', (tester) async {
    final (controller, _) = await pumpPortrait(tester);
    controller.markHandRevealed();
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 손패 한 장을 눌러 선택 상태를 만듭니다.
    await tester.tap(find.byType(Image).last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    await rotateAndBack(tester, at: '카드 선택');
  });
}
