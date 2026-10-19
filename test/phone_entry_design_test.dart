import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/template_game.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());

  testWidgets('휴대폰 로비 단계는 기존 화면을 밀지 않고 대각선 그라데이션으로 덮는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            key: const ValueKey('phone-flow-origin'),
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  PhoneFlowRoute<void>(
                    builder: (_) => const Scaffold(
                      key: ValueKey('phone-flow-next'),
                      body: SizedBox.expand(),
                    ),
                  ),
                ),
                child: const Text('다음'),
              ),
            ),
          ),
        ),
      ),
    );
    final originBefore = tester.getRect(
      find.byKey(const ValueKey('phone-flow-origin')),
    );

    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final next = find.byKey(const ValueKey('phone-flow-next'));
    expect(
      find.ancestor(
        of: next,
        matching: find.byKey(const Key('phone-flow-background-reveal')),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: next, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.ancestor(of: next, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('phone-flow-origin'))),
      originBefore,
    );

    await tester.pumpAndSettle();
    expect(next, findsOneWidget);
  });

  testWidgets('빠른 연속 배경 변경은 진행 중 경계를 튀게 하지 않고 마지막 색을 이어서 덮는다', (tester) async {
    var color = MosiColors.violet;
    late StateSetter changeColor;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            changeColor = setState;
            return PhoneBackgroundWipe(
              color: color,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );

    changeColor(() => color = MosiColors.lime);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final firstReveal = tester.widget<PhoneBackgroundReveal>(
      find.byKey(const Key('phone-background-wipe-reveal')),
    );
    expect(firstReveal.color, MosiColors.lime);
    expect(firstReveal.progress, inExclusiveRange(0, 1));

    changeColor(() => color = MosiColors.coral);
    await tester.pump();
    expect(
      tester
          .widget<PhoneBackgroundReveal>(
            find.byKey(const Key('phone-background-wipe-reveal')),
          )
          .color,
      MosiColors.lime,
    );
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump(const Duration(milliseconds: 100));

    final queuedReveal = tester.widget<PhoneBackgroundReveal>(
      find.byKey(const Key('phone-background-wipe-reveal')),
    );
    expect(queuedReveal.color, MosiColors.coral);
    expect(queuedReveal.progress, inExclusiveRange(0, 1));
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('phone-background-wipe-base')),
          )
          .color,
      MosiColors.lime,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('책장은 $width 폭에서 순서대로 스와이프·점 선택한다', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final games = ['liars_poker', 'final_call', 'mafia']
          .map(
            (id) => GameInfo.fromJson({
              'id': id,
              'name': id,
              'minPlayers': 2,
              'maxPlayers': 6,
              'playTime': 20,
            }),
          )
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: MosiColors.violet,
            body: Column(
              children: [PhoneOwnGameList(games: Future.value(games))],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('phone-book-shelf')),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('final_call'), findsOneWidget);
      // 옆 책등도 같은 이름표를 가지므로 마지막(점 버튼)을 누릅니다.
      await tester.tap(find.bySemanticsLabel('mafia 선택').last);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('phone-book-shelf')),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('스캔→코드 입력→오류→스캔은 같은 route에서 동작하며 중복 검증을 막는다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = MobileScannerPlatform.instance;
    final camera = FakeEntryCamera();
    MobileScannerPlatform.instance = camera;
    addTearDown(() {
      MobileScannerPlatform.instance = original;
      camera.captures.close();
    });
    final response = Completer<Object?>();
    var requests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec(),
    );
    messenger.setMockDecodedMessageHandler(channel, (call) {
      requests++;
      expect(((call as List).first as Map)['parameters'], {
        'roomCode': 'K7Q2M',
        'presenceProtocol': 2,
      });
      return response.future;
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    final observer = _Observer();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const PhoneRoomJoin(gameCatalog: EmptyGameCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(camera.starts, 1);
    expect(find.text('어느 방에 들어갈까요?'), findsOneWidget);
    expect(find.byType(PhoneFlowContentSwap), findsWidgets);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k7q');
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsNothing);
    expect(camera.stops, greaterThan(0));
    expect(find.text('2글자 더 입력해 주세요'), findsOneWidget);
    expect(find.byType(MosiButton), findsNothing);
    // 기기 키보드 대신 전용 자판으로 나머지 두 글자를 넣고 지웠다 다시 넣습니다.
    final keyboard = find.byKey(const ValueKey('room-code-keyboard'));
    expect(keyboard, findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.none,
    );
    expect(find.text('3 / 5'), findsOneWidget);
    await tester.tap(find.descendant(of: keyboard, matching: find.text('2')));
    await tester.tap(find.descendant(of: keyboard, matching: find.text('X')));
    await tester.pump();
    expect(find.text('5 / 5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('지우기'));
    await tester.pump();
    expect(find.text('4 / 5'), findsOneWidget);
    await tester.tap(find.descendant(of: keyboard, matching: find.text('M')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'K7Q2M',
    );
    expect(
      tester.getRect(find.byType(MosiButton)).bottom,
      lessThanOrEqualTo(tester.getRect(keyboard).top),
    );
    expect(tester.getRect(keyboard).bottom, 700);
    await tester.tap(find.byType(MosiButton));
    await tester.pump();
    expect(requests, 0);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester
          .widget<FractionalTranslation>(
            find.byKey(const Key('room-code-keyboard-slide')),
          )
          .translation
          .dy,
      inExclusiveRange(0, 1),
    );
    expect(find.text('방 코드 입력'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.byType(MosiButton));
    await tester.pump(const Duration(milliseconds: 160));
    expect(requests, 1);
    response.complete(['not-found', '존재하지 않는 방입니다.', null]);
    await tester.pumpAndSettle();
    expect(find.text('존재하지 않는 참여 코드입니다.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pumpAndSettle();
    expect(find.text('존재하지 않는 참여 코드입니다.'), findsNothing);
    await tester.tap(find.text('QR로 찍기'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(camera.starts, 2);
    expect(observer.pushes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('카메라 거절 후에도 수동 입력이 가능하고 영문·숫자만 입력된다', (tester) async {
    final original = MobileScannerPlatform.instance;
    final camera = FakeEntryCamera()..denied = true;
    MobileScannerPlatform.instance = camera;
    addTearDown(() {
      MobileScannerPlatform.instance = original;
      camera.captures.close();
    });
    await tester.pumpWidget(
      const MaterialApp(home: PhoneRoomJoin(gameCatalog: EmptyGameCatalog())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('카메라를 사용할 수 없어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ab-12가3');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'AB123',
    );
    expect(find.text('입력 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class FakeEntryCamera extends MobileScannerPlatform {
  int starts = 0;
  int stops = 0;
  bool denied = false;
  final captures = StreamController<BarcodeCapture?>.broadcast();
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: MosiColors.navy);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(300, 300),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}
