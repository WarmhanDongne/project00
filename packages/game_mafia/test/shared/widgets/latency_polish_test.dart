import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/phone/widgets/night_action_view.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/shared/widgets/delayed_connection_hint.dart';
import 'package:game_mafia/shared/widgets/profile_image.dart';
import 'package:game_mafia/tablet/screens/phase_views.dart';

void main() {
  testWidgets('짧은 연결 끊김은 숨기고 오래 끊겼을 때만 안내한다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MafiaDelayedConnectionHint(
                connectionChanges: connection.stream,
                delay: const Duration(seconds: 2),
              ),
            ],
          ),
        ),
      ),
    );

    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(_hintOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_hintOpacity(tester), 1);

    connection.add(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(_hintOpacity(tester), 0);
  });

  testWidgets('게임 인물 이미지는 프로필 URL 대신 방 캐릭터만 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: MafiaProfileImage(
            url: 'https://example.com/profile.png',
            characterId: 'frog',
          ),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.any((image) => image.image is NetworkImage), isFalse);
    expect(
      images.any(
        (image) =>
            image.image is AssetImage &&
            // 예전 동물 id(frog)는 같은 자리의 포커페이스(burger)로 그립니다.
            (image.image as AssetImage).assetName.endsWith('/burger.webp'),
      ),
      isTrue,
    );
  });

  testWidgets('밤 선택 완료와 조사 결과에 중간 연출을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 402,
          height: 874,
          child: MafiaNightActionView(
            role: MafiaRoles.mafia,
            isSubmitted: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('mafia-submission-confirmation')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 402,
          height: 874,
          child: MafiaNightActionView(
            role: MafiaRoles.police,
            investigationResult: const MafiaNightInvestigationResult(
              target: MafiaPlayer(
                uid: 'target',
                nickname: '대상',
                profileImageUrl: 'https://example.com/ignored.png',
                characterId: 'owl',
                seatIndex: 1,
              ),
              verdict: '마피아',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mafia-investigation-reveal')),
      findsOneWidget,
    );
    expect(find.text('조사 결과'), findsOneWidget);
  });

  testWidgets('태블릿 밤 마무리는 새벽 전환 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 800,
            child: MafiaTabletNightView(isWrappingUp: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('mafia-night-wrap-up-text')),
      findsOneWidget,
    );
    expect(find.text('밤이 지나가고 있습니다'), findsOneWidget);
  });
}

double _hintOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
