import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';

void main() {
  const players = [
    PlayerLayoutPlayer(
      uid: 'player-1',
      nickname: '첫 번째',
      profileImageUrl: '',
      isHost: false,
      seatIndex: 0,
    ),
    PlayerLayoutPlayer(
      uid: 'player-2',
      nickname: '두 번째',
      profileImageUrl: '',
      isHost: false,
      seatIndex: 1,
    ),
    PlayerLayoutPlayer(
      uid: 'player-3',
      nickname: '세 번째',
      profileImageUrl: '',
      isHost: false,
      seatIndex: 2,
    ),
  ];

  test('플레이어 수와 좌석 순서를 관리한다', () {
    const layout = PlayerLayoutModel(players: players);

    final updated = layout.updateSeats([2, 0, 1]);

    expect(updated.playerCount, 3);
    expect(updated.seatIndexes, [2, 0, 1]);
    expect(updated.playerByUid('player-2')?.seatIndex, 0);
  });

  test('중복되거나 범위를 벗어난 좌석은 거부한다', () {
    const layout = PlayerLayoutModel(players: players);

    expect(() => layout.updateSeats([0, 0, 2]), throwsArgumentError);
    expect(() => layout.updateSeats([0, 1, 3]), throwsArgumentError);
  });
}
