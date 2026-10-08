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
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());

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
      expect(find.text('파이널콜'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('mafia 선택'));
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
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k7q');
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsNothing);
    expect(camera.stops, greaterThan(0));
    expect(find.text('2글자 더 입력해 주세요'), findsOneWidget);
    expect(find.byType(MosiButton), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    await tester.enterText(find.byType(TextField), 'k7q2m');
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(MosiButton)).bottom,
      lessThanOrEqualTo(410),
    );
    await tester.tap(find.byType(MosiButton));
    await tester.pump();
    await tester.tap(find.byType(MosiButton));
    await tester.pump();
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
