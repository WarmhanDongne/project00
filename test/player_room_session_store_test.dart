import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('휴대폰 방 세션은 앱 재실행용 정보를 저장하고 명시적으로 지운다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlayerRoomSessionStore.instance;
    await store.clear();

    await store.save(
      uid: 'player-1',
      roomCode: 'abc12',
      nickname: '테스터',
      accentColor: '#6557d2',
    );

    final restored = await store.load();
    expect(restored?.uid, 'player-1');
    expect(restored?.roomCode, 'ABC12');
    expect(restored?.nickname, '테스터');
    expect(restored?.accentColor, '#6557D2');

    await store.clear(onlyRoomCode: 'ABC12');
    expect(await store.load(), isNull);
  });
}
