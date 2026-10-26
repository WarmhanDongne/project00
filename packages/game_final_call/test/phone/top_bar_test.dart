import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/widgets/top_bar.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

/// 태블릿이 최종 카드를 공개하는 중인 휴대폰 상태입니다.
class _Revealing extends Fake implements FinalCallController {
  @override
  bool get isEliminated => false;
  @override
  bool get isFinished => false;
  @override
  String get status => 'playing';
  @override
  String get phase => 'roundResult';
  @override
  int? get turnDeadlineAt => null;
  @override
  String? get turnUid => null;
  @override
  FinalCallPlayer? get turnPlayer => null;
  @override
  String? get callerUid => 'caller';
  @override
  String get uid => 'me';
  @override
  bool get isFinalSubmitPhase => false;
  @override
  bool get isMyTurn => false;
  @override
  Map<String, FinalCallPlayer> get players => const {};
  @override
  bool get showsEliminated => false;
  @override
  FinalCallPlayer? displayedPlayer(String playerUid) => players[playerUid];
}

void main() {
  testWidgets('태블릿 공개 중에는 알릴 내용이 없으면 빈 흰 상자를 그리지 않는다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinalCallPhoneTopBar(
            controller: _Revealing(),
            onExitRoom: () {},
            onRulesPressed: (_) {},
          ),
        ),
      ),
    );
    // 가운데 상태 알약(FinalCallPopBox)이 아예 그려지지 않습니다.
    expect(find.byType(FinalCallPopBox), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
