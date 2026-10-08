import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';

/// 다운로드 에셋 대신 1×1 투명 이미지를 돌려주는 테스트용 저장소입니다.
class FakeHoldemAssetStore extends GameAssetStore {
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  ImageProvider remoteImageProviderFor({
    required String gameId,
    required int assetVersion,
    required String logicalPath,
  }) => MemoryImage(_pixel);
}

HoldemCardModel card(String rank, String suit) =>
    HoldemCardModel(id: '${rank}_$suit', rank: rank, suit: suit);

HoldemPlayerModel player(
  String uid,
  String nickname,
  int seatIndex, {
  int stack = 1000,
  String status = 'alive',
  String handStatus = 'active',
  int streetContribution = 0,
  int totalContribution = 0,
}) => HoldemPlayerModel(
  uid: uid,
  nickname: nickname,
  characterId: 'frog',
  seatIndex: seatIndex,
  stack: stack,
  status: status,
  handStatus: handStatus,
  streetContribution: streetContribution,
  totalContribution: totalContribution,
);

HoldemGameState playingState({
  String phase = 'flop',
  String? turnUid = 'me',
  HoldemLegalActionsModel? legalActions,
  HoldemHandResultModel? result,
  HoldemLastActionModel? lastAction,
  List<HoldemCardModel>? hand,
  Map<String, HoldemPlayerModel>? players,
}) => HoldemGameState.initial().copyWith(
  loading: false,
  status: 'playing',
  phase: phase,
  handNumber: 2,
  revision: 9,
  dealerUid: 'rival',
  smallBlindUid: 'me',
  bigBlindUid: 'rival',
  communityCards: [
    card('k', 'spades'),
    card('9', 'hearts'),
    card('4', 'clubs'),
  ],
  potTotal: 1800,
  turnUid: turnUid,
  turnDeadlineAt: DateTime.now().millisecondsSinceEpoch + 18000,
  currentBet: 400,
  minimumRaise: 400,
  players:
      players ??
      {
        'me': player('me', '민지', 0, stack: 4900),
        'rival': player('rival', '하준', 1, stack: 5800, streetContribution: 400),
      },
  hand: hand ?? [card('k', 'diamonds'), card('q', 'diamonds')],
  legalActions: legalActions,
  handRank: const HoldemHandRankModel(category: 'onePair', bestCards: []),
  lastAction: lastAction,
  result: result,
);

const callOrRaise = HoldemLegalActionsModel(
  fold: true,
  check: false,
  call: true,
  bet: false,
  raise: true,
  allIn: true,
  toCall: 400,
  callAmount: 400,
  minimumTarget: 800,
  maximumTarget: 4900,
);
