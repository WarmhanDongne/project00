import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_day_view.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_execution_view.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_night_bird.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_result_view.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_tally_view.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';

//=======================가로 화면 폭발 점검==============================
// 태블릿은 항상 가로입니다. 모든 태블릿 화면을 여러 가로 크기로 실제로 펌프해서
// 레이아웃 오버플로·범위 초과·assert가 터지지 않는지 훑습니다.
// (오버플로와 예외는 테스트에서 자동으로 실패가 됩니다)
//
// 실제로 이 점검이 잡은 버그: 역할 배분 연출이 좌석판 크기 없이 좌석 번호만
// 넘겨서, 12인 방에 흩어져 앉으면 좌석을 찾다가 assert가 터졌습니다.

/// 12인 방에 4명이 **흩어져 앉은** 상황입니다. 좌석 번호가 인원수보다 큽니다.
List<MafiaPlayer> scatteredPlayers() => const [
  MafiaPlayer(uid: 'u0', nickname: '플레이어0', profileImageUrl: '', seatIndex: 1),
  MafiaPlayer(uid: 'u1', nickname: '플레이어1', profileImageUrl: '', seatIndex: 5),
  MafiaPlayer(uid: 'u2', nickname: '플레이어2', profileImageUrl: '', seatIndex: 8),
  MafiaPlayer(uid: 'u3', nickname: '플레이어3', profileImageUrl: '', seatIndex: 11),
];

/// 태블릿에서 흔한 가로 크기들입니다. 시안(1194×834)과 비율이 다른 것도 섞습니다.
const tabletSizes = [Size(1194, 834), Size(1280, 800), Size(1024, 768)];

Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view
    ..physicalSize = Size(size.width * 2, size.height * 2)
    ..devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFE9E9E9)),
            child,
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final players = scatteredPlayers();
  final playerMap = {for (final p in players) p.uid: p};

  for (final size in tabletSizes) {
    group('${size.width.toInt()}×${size.height.toInt()}', () {
      testWidgets('역할 배분 — 흩어진 좌석에서도 터지지 않는다', (tester) async {
        await pumpAt(
          tester,
          size,
          MafiaTabletRoleDealView(players: players, confirmedCount: 2),
        );
        // 분배가 도는 동안 몇 프레임 더 돌려 좌석 계산까지 지나갑니다.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('밤 — 새 등장까지 터지지 않는다', (tester) async {
        await pumpAt(tester, size, const MafiaTabletNightView());
        // 새가 반드시 한 번 나오도록 최대 간격만큼 돌립니다.
        await tester.pump(MafiaTabletNightBird.maxGap);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(MafiaTabletNightBird.crossDuration);
      });

      testWidgets('아침 — 사망자 있음/없음', (tester) async {
        await pumpAt(
          tester,
          size,
          MafiaTabletMorningView(
            result: const MafiaMorningResult(deadUids: ['u1'], savedCount: 0),
            players: playerMap,
          ),
        );
        await pumpAt(
          tester,
          size,
          MafiaTabletMorningView(
            result: const MafiaMorningResult(deadUids: [], savedCount: 1),
            players: playerMap,
          ),
        );
      });

      testWidgets('낮 토론·투표', (tester) async {
        await pumpAt(
          tester,
          size,
          const MafiaTabletDayView(showBallotBox: false, remainingSeconds: 150),
        );
        await pumpAt(
          tester,
          size,
          const MafiaTabletDayView(showBallotBox: true),
        );
      });

      testWidgets('개표 — 12명 전원이 표를 받아도 터지지 않는다', (tester) async {
        final many = {
          for (var i = 0; i < 12; i += 1)
            'p$i': MafiaPlayer(
              uid: 'p$i',
              nickname: '플레이어$i',
              profileImageUrl: '',
              seatIndex: i,
            ),
        };
        await pumpAt(
          tester,
          size,
          MafiaTabletTallyView(
            result: MafiaVoteResult(
              tally: {for (var i = 0; i < 12; i += 1) 'p$i': 12 - i},
              executedUid: 'p0',
              tie: false,
              abstainCount: 0,
            ),
            players: many,
          ),
        );
      });

      testWidgets('처형 발표 3박자', (tester) async {
        await pumpAt(
          tester,
          size,
          MafiaTabletExecutionView(
            executed: players.first,
            executedRole: MafiaRoles.find('mafia'),
            isTie: false,
          ),
        );
        await tester.pump(MafiaTabletExecutionView.nameHold);
        await tester.pump(MafiaTabletExecutionView.cardHold);
        await tester.pump(MafiaTabletExecutionView.flipDuration);
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('결과 — 포스터와 명단', (tester) async {
        await pumpAt(
          tester,
          size,
          MafiaTabletResultView(
            winner: MafiaFaction.mafia,
            players: playerMap,
            revealedRoles: {
              'u0': MafiaRoles.find('mafia'),
              'u1': MafiaRoles.find('police'),
              'u2': MafiaRoles.find('doctor'),
              'u3': MafiaRoles.find('citizen'),
            },
          ),
        );
        await tester.pump(MafiaTabletResultView.posterHold);
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  }

  testWidgets('공용 골격이 아주 좁은 가로에서도 터지지 않는다', (tester) async {
    // 분할 화면처럼 시안 비율과 크게 다른 크기입니다.
    await pumpAt(
      tester,
      const Size(700, 500),
      const Stack(
        fit: StackFit.expand,
        children: [MafiaTabletSun(), MafiaTabletChrome()],
      ),
    );
  });
}
