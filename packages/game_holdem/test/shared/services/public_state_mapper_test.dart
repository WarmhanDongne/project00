import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/shared/services/public_state_mapper.dart';

void main() {
  test('공개 상태는 좌석과 테이블 카드만 변환하고 개인 손패는 무시한다', () {
    final snapshot = HoldemPublicSnapshot.fromValue({
      'status': 'playing',
      'phase': 'flop',
      'handNumber': 3,
      'revision': 17,
      'dealerUid': 'u1',
      'smallBlindUid': 'u2',
      'bigBlindUid': 'u3',
      'smallBlind': 20,
      'bigBlind': 40,
      'communityCards': [
        {'id': 'hA', 'rank': 'A', 'suit': 'hearts'},
        {'id': 'sK', 'rank': 'K', 'suit': 'spades'},
        {'id': 'c2', 'rank': '2', 'suit': 'clubs'},
      ],
      'potTotal': 180,
      'turnUid': 'u2',
      'turnDeadlineAt': 123456,
      'currentBet': 40,
      'minimumRaise': 40,
      'players': {
        'u1': {
          'nickname': '민호',
          'characterId': 'frog',
          'seatIndex': 2,
          'stack': 820,
          'status': 'alive',
          'handStatus': 'active',
          'streetContribution': 40,
          'totalContribution': 100,
          'hand': [
            {'id': 'private-card'},
          ],
        },
      },
      'hand': [
        {'id': 'top-level-private-card'},
      ],
    });

    expect(snapshot.status, 'playing');
    expect(snapshot.phase, 'flop');
    expect(snapshot.handNumber, 3);
    expect(snapshot.revision, 17);
    expect(snapshot.communityCards.map((card) => card.id), ['hA', 'sK', 'c2']);
    expect(snapshot.players['u1']?.seatIndex, 2);
    expect(snapshot.players['u1']?.stack, 820);
    expect(snapshot.players['u1']?.handStatus, 'active');
    expect(snapshot.potTotal, 180);
  });

  test('쇼다운 결과와 다중 중단 원인을 안전하게 변환한다', () {
    final snapshot = HoldemPublicSnapshot.fromValue({
      'result': {
        'reason': 'showdown',
        'winnerUids': ['u2'],
        'awards': {'u2': 320},
        'revealedHands': {
          'u2': [
            {'id': 'dQ', 'rank': 'Q', 'suit': 'diamonds'},
            {'id': 'dJ', 'rank': 'J', 'suit': 'diamonds'},
          ],
        },
        'handCategories': {'u2': 'flush'},
        'bestCards': {
          'u2': [
            {'id': 'dA', 'rank': 'a', 'suit': 'diamonds'},
            {'id': 'dQ', 'rank': 'q', 'suit': 'diamonds'},
            {'id': 'dJ', 'rank': 'j', 'suit': 'diamonds'},
            {'id': 'd7', 'rank': '7', 'suit': 'diamonds'},
            {'id': 'd2', 'rank': '2', 'suit': 'diamonds'},
          ],
        },
      },
      'lastAction': {
        'uid': 'u1',
        'kind': 'raise',
        'amount': 120,
        'createdAt': 55,
      },
      'recovery': {
        'paused': true,
        'pauseId': 'pause-current',
        'causes': {
          'player:u3': {
            'uid': 'u3',
            'role': 'player',
            'incidentId': 'incident-three',
            'deadlineAt': 999999,
            'canContinue': true,
          },
          'controller:t': {'uid': 't', 'role': 'controller'},
        },
      },
    });

    expect(snapshot.result?.reason, 'showdown');
    expect(snapshot.result?.winnerUids, ['u2']);
    expect(snapshot.result?.awards, {'u2': 320});
    expect(snapshot.result?.revealedHands['u2']?.map((card) => card.id), [
      'dQ',
      'dJ',
    ]);
    expect(snapshot.result?.handCategories['u2'], 'flush');
    expect(snapshot.result?.bestCards['u2'], hasLength(5));
    expect(snapshot.lastAction?.uid, 'u1');
    expect(snapshot.lastAction?.kind, 'raise');
    expect(snapshot.lastAction?.amount, 120);
    expect(snapshot.interruption, isNotNull);
    expect(snapshot.interruption!.causes, hasLength(2));
    expect(snapshot.interruption!.playerUid, 'u3');
    expect(snapshot.interruption!.eligibleVoterUids, isEmpty);
    expect(snapshot.interruption!.canContinue, isTrue);
  });

  test('잘못된 공개 상태는 UI가 처리할 수 있는 기본값으로 변환한다', () {
    final snapshot = HoldemPublicSnapshot.fromValue('invalid');

    expect(snapshot.status, 'waiting');
    expect(snapshot.phase, 'waiting');
    expect(snapshot.handNumber, 1);
    expect(snapshot.smallBlind, 10);
    expect(snapshot.bigBlind, 20);
    expect(snapshot.communityCards, isEmpty);
    expect(snapshot.players, isEmpty);
    expect(snapshot.result, isNull);
    expect(snapshot.lastAction, isNull);
    expect(snapshot.interruption, isNull);
  });

  test('구버전 서버 결과에 최종 5장이 없으면 빈 값으로 둔다', () {
    final snapshot = HoldemPublicSnapshot.fromValue({
      'result': {
        'reason': 'fold',
        'winnerUids': ['u1'],
        'awards': {'u1': 30},
      },
    });

    expect(snapshot.result?.bestCards, isEmpty);
    expect(snapshot.result?.revealedHands, isEmpty);
  });
}
