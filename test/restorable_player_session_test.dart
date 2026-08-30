import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

void main() {
  group('restorablePlayerSession', () {
    test('allows an active player to return to a waiting room', () {
      expect(
        restorablePlayerSession(
          playerExists: true,
          playerStatus: 'active',
          roomStatus: 'waiting',
          selectedGameId: null,
          gameStatus: null,
          privateGameDataExists: false,
        ),
        RestorableSession.waitingRoom,
      );
    });

    test('allows an active player to return while seating is in progress', () {
      expect(
        restorablePlayerSession(
          playerExists: true,
          playerStatus: 'active',
          roomStatus: 'seating',
          selectedGameId: 'liars_poker',
          gameStatus: null,
          privateGameDataExists: false,
        ),
        RestorableSession.waitingRoom,
      );
    });

    test('ignores stale finished game data in waiting and seating rooms', () {
      for (final roomStatus in ['waiting', 'seating']) {
        expect(
          restorablePlayerSession(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: roomStatus,
            selectedGameId: null,
            gameStatus: 'finished',
            privateGameDataExists: false,
          ),
          RestorableSession.waitingRoom,
        );
      }
    });

    test(
      'allows return only when an active game has complete authority data',
      () {
        expect(
          restorablePlayerSession(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: 'playing',
            privateGameDataExists: true,
          ),
          RestorableSession.activeGame,
        );
        expect(
          restorablePlayerSession(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: null,
            gameStatus: 'playing',
            privateGameDataExists: true,
          ),
          RestorableSession.none,
        );
        expect(
          restorablePlayerSession(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: null,
            privateGameDataExists: true,
          ),
          RestorableSession.none,
        );
        expect(
          restorablePlayerSession(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: 'playing',
            privateGameDataExists: false,
          ),
          RestorableSession.none,
        );
      },
    );

    test('rejects finished, closed, removed, and inactive sessions', () {
      for (final state
          in <
            ({
              bool playerExists,
              String? playerStatus,
              String? roomStatus,
              String? gameStatus,
            })
          >[
            (
              playerExists: true,
              playerStatus: 'active',
              roomStatus: 'finished',
              gameStatus: 'finished',
            ),
            (
              playerExists: true,
              playerStatus: 'active',
              roomStatus: 'closed',
              gameStatus: null,
            ),
            (
              playerExists: false,
              playerStatus: null,
              roomStatus: 'waiting',
              gameStatus: null,
            ),
            (
              playerExists: true,
              playerStatus: 'inactive',
              roomStatus: 'waiting',
              gameStatus: null,
            ),
          ]) {
        expect(
          restorablePlayerSession(
            playerExists: state.playerExists,
            playerStatus: state.playerStatus,
            roomStatus: state.roomStatus,
            selectedGameId: 'liars_poker',
            gameStatus: state.gameStatus,
            privateGameDataExists: false,
          ),
          RestorableSession.none,
        );
      }
    });
  });
}
