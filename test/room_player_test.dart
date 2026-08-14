import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

void main() {
  test('joinedAt 이후 30초 동안만 NEW 남은 시간을 반환한다', () {
    final joinedAt = DateTime(2026, 8, 15, 12);
    final player = RoomPlayer.fromJson({
      'uid': 'uid1',
      'nickname': '플레이어',
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    });

    expect(
      player.newBadgeRemainingAt(joinedAt.add(const Duration(seconds: 10))),
      const Duration(seconds: 20),
    );
    expect(
      player.newBadgeRemainingAt(joinedAt.add(const Duration(seconds: 30))),
      Duration.zero,
    );
    expect(
      player.newBadgeRemainingAt(joinedAt.add(const Duration(seconds: 45))),
      Duration.zero,
    );
  });
}
