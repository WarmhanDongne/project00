import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/dev/mafia_practice_engine.dart';
import 'package:project00/games/mafia/dev/mafia_practice_remote_service.dart';
import 'package:project00/games/mafia/dev/mafia_practice_server.dart';

//=======================연습 서버 ↔ 폰 접속 통합 테스트========================
// 실제 loopback 소켓으로 폰 2대 접속 → 자리 배정 → 상태 수신 → 명령 왕복을
// 확인합니다. 위젯 가짜 시간과 소켓이 섞이면 안 되므로 test()로 돌립니다.
void main() {
  test('폰 두 대가 자리(p1·p2)를 받고 명령이 엔진까지 간다', () async {
    final engine = MafiaPracticeEngine(
      playerCount: 5,
      humanUids: const ['p1', 'p2'],
      botDelay: const Duration(milliseconds: 1),
    );
    // 봇이 스스로 진행하지 않게 멈춰 두고 명령 왕복만 봅니다.
    engine.autoPlay = false;
    final server = MafiaPracticeServer();
    // 포트 0 = 비어 있는 포트 자동 선택. 다른 테스트와 충돌하지 않습니다.
    await server.start(engine, port: 0);
    final port = server.port!;

    final phone1 = await MafiaPracticeRemoteClient.connect(port: port);
    final phone2 = await MafiaPracticeRemoteClient.connect(port: port);
    expect({phone1.uid, phone2.uid}, {'p1', 'p2'});
    expect(phone1.nickname, isNotEmpty);

    // 폰1이 역할을 확인하면 모두의 공개 상태에 반영됩니다.
    final updated = phone1.service.query
        .watchPublicGame('REMOTE')
        .map((event) => event.snapshot.value as Map?)
        .firstWhere(
          (map) =>
              ((map?['roleRevealedUids'] as List?) ?? const []).contains('p1'),
        );
    await phone1.service.command.confirmRole(roomCode: 'REMOTE');
    await updated.timeout(const Duration(seconds: 5));

    // 새 판(엔진 교체) 뒤에도 소켓 재접속 없이 이어집니다.
    final engine2 = MafiaPracticeEngine(
      playerCount: 4,
      humanUids: const ['p1', 'p2'],
    );
    engine2.autoPlay = false;
    await server.start(engine2, port: port);
    final fresh = await phone2.service.query
        .watchPublicGame('REMOTE')
        .map((event) => event.snapshot.value as Map?)
        .firstWhere((map) => (map?['players'] as Map?)?.length == 4)
        .timeout(const Duration(seconds: 5));
    expect((fresh?['roleRevealedUids'] as List?) ?? const [], isEmpty);

    phone1.close();
    phone2.close();
    await server.stop();
    engine.dispose();
    engine2.dispose();
  });

  test(
    '호스트가 내려가면 폰이 끊김을 감지한다',
    () async {
      final engine = MafiaPracticeEngine(
        playerCount: 4,
        humanUids: const ['p1'],
      );
      engine.autoPlay = false;
      final server = MafiaPracticeServer();
      await server.start(engine, port: 0);
      final phone = await MafiaPracticeRemoteClient.connect(port: server.port!);
      expect(phone.connected.value, isTrue);

      await server.stop();
      // 소켓 종료 전파를 기다립니다.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(phone.connected.value, isFalse);

      phone.close();
      engine.dispose();
    },
    onPlatform: {'!vm': const Skip('dart:io 소켓은 VM에서만 돕니다.')},
  );
}
