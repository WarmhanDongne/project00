import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

void main() {
  group('isRestorablePlayerSessionState', () {
    test('allows an active player to return to a waiting room', () {
      expect(
        isRestorablePlayerSessionState(
          playerExists: true,
          playerStatus: 'active',
          roomStatus: 'waiting',
          selectedGameId: null,
          gameStatus: null,
          privateGameDataExists: false,
        ),
        isTrue,
      );
    });

    test('allows an active player to return while seating is in progress', () {
      expect(
        isRestorablePlayerSessionState(
          playerExists: true,
          playerStatus: 'active',
          roomStatus: 'seating',
          selectedGameId: 'liars_poker',
          gameStatus: null,
          privateGameDataExists: false,
        ),
        isTrue,
      );
    });

    test(
      'allows return only when an active game has complete authority data',
      () {
        expect(
          isRestorablePlayerSessionState(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: 'playing',
            privateGameDataExists: true,
          ),
          isTrue,
        );
        expect(
          isRestorablePlayerSessionState(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: null,
            gameStatus: 'playing',
            privateGameDataExists: true,
          ),
          isFalse,
        );
        expect(
          isRestorablePlayerSessionState(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: null,
            privateGameDataExists: true,
          ),
          isFalse,
        );
        expect(
          isRestorablePlayerSessionState(
            playerExists: true,
            playerStatus: 'active',
            roomStatus: 'playing',
            selectedGameId: 'liars_poker',
            gameStatus: 'playing',
            privateGameDataExists: false,
          ),
          isFalse,
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
          isRestorablePlayerSessionState(
            playerExists: state.playerExists,
            playerStatus: state.playerStatus,
            roomStatus: state.roomStatus,
            selectedGameId: 'liars_poker',
            gameStatus: state.gameStatus,
            privateGameDataExists: false,
          ),
          isFalse,
        );
      }
    });
  });
}
