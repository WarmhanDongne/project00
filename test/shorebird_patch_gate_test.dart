import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/update/shorebird_patch_gate.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

//=======================Shorebird 패치 배선==============================
// 패치는 있으면 좋은 것이라, 확인이 늦거나 실패해도 앱은 그대로 써야 합니다.
// 패치 화면에는 끝나지 않는 움직임(그림 흔들림·점·별)이 있어 pumpAndSettle
// 대신 시간을 정해 흘려보냅니다.
void main() {
  Future<void> pumpGate(WidgetTester tester, _FakeUpdater updater) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ShorebirdPatchGate(updater: updater, child: const Text('앱 화면')),
      ),
    );
  }

  testWidgets('업데이터가 없는 빌드에서는 확인조차 하지 않는다', (tester) async {
    final updater = _FakeUpdater(available: false);

    await pumpGate(tester, updater);
    await tester.pump();

    expect(updater.checkCalls, 0);
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('받을 패치가 없으면 앱 화면을 가리지 않는다', (tester) async {
    final updater = _FakeUpdater(status: UpdateStatus.upToDate);

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));

    expect(updater.updateCalls, 0);
    expect(find.text('앱 화면'), findsOneWidget);
    expect(find.text('업데이트를 받는 중'), findsNothing);
  });

  testWidgets('확인하는 동안에는 앱 화면을 막지 않는다', (tester) async {
    final check = Completer<UpdateStatus>();
    final updater = _FakeUpdater(checkCompleter: check);

    await pumpGate(tester, updater);
    await tester.pump();

    // 확인이 끝나지 않았는데도 앱은 이미 쓸 수 있습니다.
    expect(find.text('앱 화면'), findsOneWidget);

    check.complete(UpdateStatus.upToDate);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('새 패치가 있으면 받는 동안 패치 화면을 보여 준다', (tester) async {
    final download = Completer<void>();
    final updater = _FakeUpdater(
      status: UpdateStatus.outdated,
      updateCompleter: download,
    );

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));

    expect(updater.updateCalls, 1);
    expect(find.text('업데이트를 받는 중'), findsOneWidget);
    expect(find.text('앱 화면'), findsNothing);

    download.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 패치는 다시 켤 때 적용되므로, 알린 뒤 바로 앱으로 넘어갈 수 있습니다.
    expect(find.text('업데이트를 마쳤어요'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('앱으로 돌아오면 다시 확인한다', (tester) async {
    // 켤 때 네트워크가 아직 붙지 않았거나 사용자가 건너뛴 경우, 그 세션 내내
    // 패치를 못 받으면 안 됩니다.
    final updater = _FakeUpdater(status: UpdateStatus.upToDate);

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));
    expect(updater.checkCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));

    expect(updater.checkCalls, 2);
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('이미 받아 둔 패치가 있으면 다시 확인하지 않는다', (tester) async {
    final updater = _FakeUpdater(status: UpdateStatus.outdated);

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(updater.updateCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));

    // 받아 둔 패치는 다음 실행에 적용됩니다. 다시 받지 않습니다.
    expect(updater.checkCalls, 1);
    expect(updater.updateCalls, 1);
  });

  testWidgets('게임 화면이 올라와 있으면 패치 화면을 덮지 않는다', (tester) async {
    final updater = _FakeUpdater(status: UpdateStatus.upToDate);
    final navigator = GlobalKey<NavigatorState>();

    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ShorebirdPatchGate(updater: updater, child: const Text('앱 화면')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // 게임에 들어간 뒤 앱으로 돌아온 상황입니다.
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('게임 화면')),
      ),
    );
    await tester.pumpAndSettle();
    updater.status = UpdateStatus.outdated;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 내려받기는 조용히 진행되고, 진행 중인 게임을 가리지 않습니다.
    expect(updater.updateCalls, 1);
    expect(find.text('업데이트를 받는 중'), findsNothing);
    expect(find.text('업데이트를 마쳤어요'), findsNothing);
    expect(find.text('게임 화면'), findsOneWidget);
  });

  testWidgets('내려받기가 실패해도 앱은 그대로 쓴다', (tester) async {
    final updater = _FakeUpdater(
      status: UpdateStatus.outdated,
      updateError: const UpdateException(
        message: 'download failed',
        reason: UpdateFailureReason.downloadFailed,
      ),
    );

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('앱 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 받아 둔 패치가 있으면 다시 안내하지 않는다', (tester) async {
    final updater = _FakeUpdater(status: UpdateStatus.restartRequired);

    await pumpGate(tester, updater);
    await tester.pump(const Duration(milliseconds: 400));

    expect(updater.updateCalls, 0);
    expect(find.text('앱 화면'), findsOneWidget);
  });
}

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    this.available = true,
    this.status = UpdateStatus.upToDate,
    this.checkCompleter,
    this.updateCompleter,
    this.updateError,
  });

  final bool available;
  UpdateStatus status;
  final Completer<UpdateStatus>? checkCompleter;
  final Completer<void>? updateCompleter;
  final Object? updateError;

  int checkCalls = 0;
  int updateCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    checkCalls += 1;
    final completer = checkCompleter;
    if (completer != null) return completer.future;
    return status;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    updateCalls += 1;
    if (updateCompleter != null) await updateCompleter!.future;
    final error = updateError;
    if (error != null) throw error;
  }

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;
}
