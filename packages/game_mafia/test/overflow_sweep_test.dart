import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_mafia/phone/phone_board.dart';
import 'package:game_mafia/phone/providers/game_stage.dart';
import 'package:game_mafia/phone/widgets/top_bar.dart';
import 'package:game_mafia/shared/models/game_state.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/shared/services/command_service.dart';
import 'package:game_mafia/shared/services/game_service.dart';
import 'package:game_mafia/shared/services/query_service.dart';
import 'package:game_mafia/tablet/providers/game_stage.dart';
import 'package:game_mafia/tablet/screens/role_setup_screen.dart';
import 'package:game_mafia/tablet/tablet_board.dart';

import 'support/overflow_sweep.dart';

// 최대 인원 12명, 닉네임 최대 8자로 가장 긴 경우를 만듭니다.
const _names = [
  '가나다라마바사아',
  '서윤서윤서윤서윤',
  'ABCDEFGH',
  '하린하린하린하린',
  '도윤도윤도윤도윤',
  '지우지우지우지우',
  '민준민준민준민준',
  '예린예린예린예린',
  '태오태오태오태오',
  '나연나연나연나연',
  'WWWWWWWW',
  '은서은서은서은서',
];

String _uid(int i) => i == 0 ? 'me' : 'p$i';

Map<String, Object?> _players({Set<int> dead = const {}}) => {
  for (var i = 0; i < 12; i++)
    _uid(i): {
      'uid': _uid(i),
      'nickname': _names[i],
      'characterId': 'frog',
      'seatIndex': i,
      'status': dead.contains(i) ? 'dead' : 'alive',
      if (dead.contains(i)) 'deathCause': i == 2 ? 'execution' : 'nightAttack',
      if (dead.contains(i)) 'diedRound': 1,
    },
};

Map<String, Object?> _public(
  String phase, {
  Set<int> dead = const {},
  Map<String, Object?> extra = const {},
}) => {
  'status': phase == 'finished' ? 'finished' : 'playing',
  'phase': phase,
  'round': 2,
  'revision': 5,
  'turnDeadlineAt': DateTime.now().millisecondsSinceEpoch + 134000,
  'players': _players(dead: dead),
  'nightActorCount': 4,
  'nightSubmittedCount': 2,
  'voteEligibleCount': 12 - dead.length,
  'voteSubmittedCount': 5,
  'voteSubmittedUids': ['p1', 'p4', 'p5', 'p7', 'p9'],
  'discussionSkipCount': 3,
  ...extra,
};

Map<String, Object?> _private(String role) => {
  'roleId': role,
  if (role == 'mafia') 'allyUids': ['p5', 'p9'],
  if (role == 'mafia') 'allySelections': {'p5': 'p3'},
};

class _Case {
  const _Case(this.phone, this.tablet, this.public, this.role);
  final MafiaPhoneStage? phone;
  final MafiaTabletStage? tablet;
  final Map<String, Object?> public;
  final String role;
}

final _cases = <String, _Case>{
  '신분 확인': _Case(
    MafiaPhoneStage.roleReveal,
    MafiaTabletStage.roleDeal,
    _public(
      'roleReveal',
      extra: {
        'roleRevealedUids': ['p1', 'p2'],
      },
    ),
    'mafia',
  ),
  '밤 마피아': _Case(
    MafiaPhoneStage.night,
    MafiaTabletStage.night,
    _public('night', extra: {'nightStage': 'action'}),
    'mafia',
  ),
  '밤 의사': _Case(
    MafiaPhoneStage.night,
    null,
    _public('night', extra: {'nightStage': 'action'}),
    'doctor',
  ),
  '밤 시민': _Case(
    MafiaPhoneStage.night,
    null,
    _public('night', extra: {'nightStage': 'action'}),
    'citizen',
  ),
  '아침 사망': _Case(
    MafiaPhoneStage.morning,
    MafiaTabletStage.morning,
    _public(
      'morning',
      dead: {3},
      extra: {
        'morningResult': {
          'deadUids': ['p3'],
          'savedCount': 0,
        },
      },
    ),
    'citizen',
  ),
  '낮 토론': _Case(
    MafiaPhoneStage.day,
    MafiaTabletStage.day,
    _public('day', dead: {3}),
    'citizen',
  ),
  '투표': _Case(
    MafiaPhoneStage.voting,
    MafiaTabletStage.voting,
    _public('voting', dead: {3}),
    'citizen',
  ),
  '처형 결과': _Case(
    MafiaPhoneStage.voteResult,
    MafiaTabletStage.voteResult,
    _public(
      'voteResult',
      dead: {2, 3},
      extra: {
        'voteResult': {
          'tally': {'p2': 6, 'p4': 3, 'p7': 1},
          'executedUid': 'p2',
          'abstainCount': 1,
        },
        'revealedRoles': {'p2': 'mafia'},
      },
    ),
    'citizen',
  ),
  '관전': _Case(
    MafiaPhoneStage.spectator,
    null,
    _public('day', dead: {0, 3}),
    'citizen',
  ),
  '게임 끝': _Case(
    MafiaPhoneStage.result,
    MafiaTabletStage.finished,
    _public(
      'finished',
      dead: {2, 3, 6},
      extra: {
        'winner': 'mafia',
        'winnerUids': ['me', 'p5', 'p9'],
        'finishReason': 'mafiaWin',
        'revealedRoles': {
          for (var i = 0; i < 12; i++)
            _uid(i): [0, 5, 9].contains(i) ? 'mafia' : 'citizen',
        },
      },
    ),
    'mafia',
  ),
};

Future<(MafiaController, ProviderContainer)> _controller(
  WidgetTester tester,
  _Case data,
) async {
  final container = ProviderContainer();
  final provider = NotifierProvider<MafiaController, MafiaGameState>(
    () => MafiaController(
      roomCode: 'R1',
      uid: 'me',
      service: MafiaService(
        command: _Commands(),
        query: _Query(),
        interruption: _Reports(),
      ),
    ),
  );
  container.listen(provider, (_, _) {});
  final game = container.read(provider.notifier);
  game.applyPublicValue(data.public);
  game.handlePrivateEvent(_Event(_private(data.role)));
  await tester.pump();
  return (game, container);
}

PlayerLayoutModel _layout() => PlayerLayoutModel(
  players: [
    for (var i = 0; i < 12; i++)
      PlayerLayoutPlayer(
        uid: _uid(i),
        nickname: _names[i],
        characterId: 'frog',
        seatIndex: i,
      ),
  ],
);

void main() {
  testWidgets('마피아 휴대폰 화면은 모든 휴대폰 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepPhones) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: data) in _cases.entries) {
        final stage = data.phone;
        if (stage == null) continue;
        sweep.where = '휴대폰 $device $name';
        final (game, container) = await _controller(tester, data);
        final content = stage == MafiaPhoneStage.result
            ? MafiaPhoneScreens.result(
                winner: game.winnerFaction,
                winnerRoleIds: game.winnerRoleIds,
                winnerLabel: game.winnerLabel,
                players: game.orderedPlayers,
                revealedRoles: {
                  for (final player in game.orderedPlayers)
                    player.uid: game.revealedRoleOf(player.uid),
                },
                myRole: game.myRole,
                myUid: game.uid,
                didWin: game.didWin,
                allies: game.allyPlayers,
              )
            : MafiaPhoneScreens.playing(
                controller: game,
                stage: stage,
                regions: const PhoneGameRegions(
                  showTopBar: true,
                  showHand: true,
                  showTimer: true,
                  showActions: true,
                ),
              );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: sweepTheme(),
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(child: content),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: MafiaPhoneTopBar(
                          me: game.me,
                          subtitle: MafiaPhoneTopBar.subtitleFor(
                            phase: game.phase,
                            round: game.round,
                          ),
                          isNight: game.usesNightScene || game.isFinished,
                          spectating: game.isSpectating,
                          onExitRoom: () {},
                          onRulesPressed: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });

  testWidgets('마피아 태블릿 화면은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: data) in _cases.entries) {
        final stage = data.tablet;
        if (stage == null) continue;
        sweep.where = '태블릿 $device $name';
        final (game, container) = await _controller(tester, data);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: sweepTheme(),
              home: Scaffold(
                body: MafiaTabletStageView(
                  stage: stage,
                  controller: game,
                  playerLayout: _layout(),
                  remainingSeconds: 134,
                  onRulebookPressed: () {},
                  onSettingsPressed: () {},
                  onRestart: () {},
                  onHome: () {},
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
  testWidgets('마피아 역할 구성 화면은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final players in const [4, 8, 12]) {
        sweep.where = '태블릿 $device 역할 구성 $players명';
        await tester.pumpWidget(
          MaterialApp(
            theme: sweepTheme(),
            home: MafiaRoleSetupScreen(
              playerCount: players,
              onConfirm: (_) async => false,
              onCancel: () async => false,
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        // 역할 추가 목록을 연 상태도 봅니다.
        final add = find.byKey(const ValueKey('add-role'));
        if (add.evaluate().isNotEmpty) {
          sweep.where = '태블릿 $device 역할 추가 $players명';
          await tester.tap(add, warnIfMissed: false);
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          sweep.scanText(tester);
          await sweep.shot(tester, sweep.where);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Query extends Fake implements MafiaQueryService {
  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) =>
      const Stream.empty();
  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => const Stream.empty();
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async => _Snapshot(null);
}

class _Commands extends Fake implements MafiaCommandService {}

class _Reports extends Fake implements GameInterruptionCommandService {
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async => {'status': 'accepted'};
}
