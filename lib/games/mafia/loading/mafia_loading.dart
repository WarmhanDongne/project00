import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================마피아 에셋 사전 준비==============================
/// 게임 화면에서 최초 표시될 이미지와 효과음을 미리 준비합니다.
///
/// Liar's Poker의 `preloadLiarsPokerAssets`와 같은 규약입니다. 하지 않으면
/// 첫 화면(P1) 배경·카드 뒷면이 처음 디코딩되며 한 프레임 번쩍입니다.
///
/// ⚠️ 역할 카드 **앞면(30여 장, 대형)은 일부러 넣지 않습니다.** 전부
/// 디코딩하면 Flutter 이미지 캐시(기본 100MB)를 넘겨 방금 준비한 에셋부터
/// 도로 밀려납니다. 앞면은 신분 배분 뒤 카드가 올라오는 연출(0.52초) 동안
/// 디코딩할 시간이 있습니다.
///
/// 플레이어 사진은 방 캐릭터가 아니라 네트워크 프로필 URL이라 여기서
/// 준비하지 않습니다.
Future<void> preloadMafiaAssets(
  BuildContext context, {
  required bool isPhone,
}) async {
  // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행하므로 게임
  // 진입을 막지 않습니다. (initState의 호출과 중복돼도 안전합니다)
  try {
    await GameAssetStore.instance.prepareGame('mafia');
  } catch (_) {}
  if (!context.mounted) return;

  // 총성·투표·승리 효과음. 미리 풀지 않으면 첫 재생이 화면보다 늦습니다.
  unawaited(
    SoundEffects.of(context)?.preloadEffects(MafiaSounds.preloadTargets) ??
        Future<void>.value(),
  );

  final images = Assets.games.mafia.images;
  final background = images.background;
  final other = images.other;
  final localAssets = <GameImage>[
    // 기기별 낮·밤 배경과 P1의 카드 뒷면이 가장 먼저 보입니다.
    if (isPhone) ...[
      background.backgroundMorningPhone.game,
      background.backgroundNightPhone.game,
      other.talkPhone.game,
    ] else ...[
      background.backgroundMorning.game,
      background.backgroundNight.game,
      other.talkTablet.game,
      other.sun.game,
      other.moon.game,
      // 밤하늘을 지나가는 새 프레임 4장입니다.
      ...background.bird.values.game,
    ],
    images.cards.roleBack.game,
    other.deadMessage.game,
    other.voteBox.game,
    ...images.icons.values.game,
    // 승리 포스터·배너는 결과 화면 전용이라 뺐습니다. 포스터가 3.4초
    // 머무는 동안 디코딩할 시간이 충분합니다.
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
}
