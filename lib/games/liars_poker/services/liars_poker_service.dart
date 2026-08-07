import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class LiarsPokerGameService {
  final FirebaseDatabase realtime;
  final FirebaseFirestore firestore;
  final RoomProvider provider;

  List<RoomPlayer> get players => provider.players;
  int get playersCount => provider.players.length;

  LiarsPokerGameService(this.realtime, this.firestore, this.provider);

  /// 게임 시작
  Future<void> startGame({
    required String roomCode,
    required String hostUid,
    required List<RoomPlayer> players,
  }) async {
    final playersSet = {
      for (final player in players)
        player.uid: {
          'seatIndex': player.seatIndex,
          'status': 'alive',
          'penalty': {'count': 0},
        },
    };

    await realtime.ref('rooms/$roomCode/game').set({
      'players': {'public': playersSet},
      'status': 'waiting',
      'turn': 0,
      'table': null,
      'lastPlay': {'cards': [], 'lastPlayer': null},
    });
    await dealCards(roomCode: roomCode, players: players);
  }

  /// 공식 비율 덱 생성
  Future<List<String>> createDeck(int playerCount) async {
    late final Map<String, int> counts;

    switch (playerCount) {
      case 2:
        counts = {'A': 3, 'K': 3, 'Q': 3, 'Joker': 1};
        break;
      case 3:
        counts = {'A': 5, 'K': 5, 'Q': 4, 'Joker': 1};
        break;
      case 4:
        counts = {'A': 6, 'K': 6, 'Q': 6, 'Joker': 2};
        break;
      case 5:
        counts = {'A': 8, 'K': 8, 'Q': 7, 'Joker': 2};
        break;
      case 6:
        counts = {'A': 9, 'K': 9, 'Q': 9, 'Joker': 3};
        break;
      default:
        throw Exception('지원하지 않는 인원입니다.');
    }
    final deck = <String>[];
    counts.forEach((card, count) {
      deck.addAll(List.filled(count, card));
    });
    deck.shuffle(Random.secure());
    return deck;
  }

  /// 카드 분배
  Future<void> dealCards({
    required String roomCode,
    required List<RoomPlayer> players,
  }) async {
    final deck = await createDeck(players.length);

    final updates = <String, dynamic>{};

    for (final player in players) {
      final hand = deck.sublist(0, 5);
      deck.removeRange(0, 5);

      updates['rooms/$roomCode/game/players/private/${player.uid}/hand'] = hand;
    }

    await realtime.ref().update(updates);
  }

  Future<void> roundStart({required String roomCode}) async {
    final table = ['K', 'Q', 'A']..shuffle(Random.secure());

    await realtime.ref('rooms/$roomCode/game').set({'table': table.first});
  }

  Future<void> playCard({
    required String roomCode,
    required String playerUid,
    required List<String> cards,
  }) async {
    await realtime.ref('rooms/$roomCode/game/lastPlay').set({
      'cards': cards,
      'lastPlayer': playerUid,
    });
  }

  // Future<void> playLiar({
  //   required String roomCode,
  //   required String playerUid,
  //   required String table,
  //   required String turnUid,
  // }) async {
  //   final lastPlay=await realtime.ref('rooms/$roomCode/game/lastPlay').get();
  //   if(lastPlay['cards']===table){
  //     await realtime.ref('rooms/$roomCode/game/').set({
  //     'status': 'penalty',
  //   });
  //   }
  // }
}
