import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/core/diagnostics/crash_reporting.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/final_call/sound/final_call_sounds.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/models/room_character.dart';

//=======================Final Call 에셋 사전 준비==============================
/// 게임 화면에서 최초 표시될 이미지와 방 캐릭터를 미리 디코딩합니다.
///
/// Liar's Poker의 `preloadLiarsPokerAssets`와 같은 규약입니다. 하지 않으면
/// 분배 직후 손패·배경이 처음 디코딩되며 한 프레임 번쩍입니다.
///
/// 배경음악은 반복 재생이라 `GameBackgroundMusic` 전용 플레이어가 스트리밍으로
/// 처리하며 여기서 준비하지 않습니다.
Future<void> preloadFinalCallAssets(
  BuildContext context, {
  required Iterable<String> characterIds,
}) async {
  // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행하므로 게임
  // 진입을 막지 않습니다. (initState의 호출과 중복돼도 안전합니다)
  try {
    await GameAssetStore.instance.prepareGame('final_call');
  } catch (error, stack) {
    // 실패해도 번들 폴백으로 게임은 진행됩니다. 다만 원인은 남깁니다.
    CrashReporting.recordError(error, stack, reason: '파이널콜 에셋 준비');
  }
  if (!context.mounted) return;

  // 하트 파열음처럼 한 라운드에 한 번만 나는 소리가 화면보다 늦지 않도록
  // 게임 전용 효과음을 먼저 준비합니다.
  unawaited(
    SoundEffects.of(context)?.preloadEffects(FinalCallSounds.preloadTargets) ??
        Future<void>.value(),
  );

  final images = Assets.games.finalCall.images;
  final localAssets = <GameImage>[
    // 분배가 끝나면 손패가 곧바로 펼쳐지므로 카드는 전부 준비합니다.
    ...images.cards.values.game,
    ...images.background.values.game,
    ...images.button.values.game,
    ...images.icons.values.game,
    ...images.layout.values.game,
    ...images.modal.values.game,
    ...images.other.values.game,
  ];

  // 한꺼번에 모든 대형 PNG를 디코딩해 메모리가 튀지 않도록 작은 묶음으로 준비합니다.
  for (var index = 0; index < localAssets.length; index += 4) {
    final end = (index + 4).clamp(0, localAssets.length);
    await Future.wait(
      localAssets
          .sublist(index, end)
          .map((asset) => precacheImage(asset.provider(), context)),
    );
  }

  final uniqueCharacterIds = characterIds.toSet();
  await Future.wait(
    uniqueCharacterIds.map(
      (id) => precacheImage(AssetImage(roomCharacterAssetPath(id)), context),
    ),
  );
}
