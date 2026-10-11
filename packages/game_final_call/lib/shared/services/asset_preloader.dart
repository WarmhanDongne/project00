import 'package:game_kit/recovery/services/required_image.dart';
// [game_loading.dart] 는 파이널콜에서 사용하는 게임 진입 전 로딩과 준비 흐름을 관리하는 파일이다.
//
// - [Package] : 파이널콜
// - [Loading] : 게임 진입 전 로딩과 준비 흐름을 관리함
//
// 즉, 화면과 서버가 준비되기 전에 게임이 시작되지 않게 처리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_final_call/game_assets.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_final_call/game_sounds.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_kit/core/constants/room_character.dart';

// ============================================================

// ---------------------------------------------------------------------------
// Final Call 에셋 사전 준비
// ---------------------------------------------------------------------------
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
  bool isPhone = false,
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
  // 이 게임 소리를 미리 풀어 둡니다. 하지 않으면 첫 재생이 화면보다 늦습니다.
  // `scope`를 주면 다른 게임에 들어갈 때 이 소리들을 자동으로 놓아 줍니다 —
  // 쌓이면 기기 디코더가 모자라 준비가 실패합니다(2026-08 iOS 사고).
  final sound = SoundEffects.of(context);
  if (sound != null) {
    unawaited(
      sound.preloadEffects(FinalCallSounds.preloadTargets, scope: 'final_call'),
    );
    // 안내 음성은 겹쳐 나지 않으므로 사본을 하나만 둡니다.
    unawaited(
      sound.preloadEffects(
        FinalCallSounds.narrationTargets,
        solo: true,
        scope: 'final_call',
      ),
    );
  }

  // 카드·배경·버튼·하트는 모두 위젯으로 그립니다. 남은 그림은 휴대폰
  // 나가기 확인창의 문 그림뿐입니다.
  final localAssets = <GameImage>[
    if (isPhone) Assets.games.finalCall.images.modal.modalImageDoor.game,
  ];

  // 한꺼번에 모든 대형 PNG를 디코딩해 메모리가 튀지 않도록 작은 묶음으로 준비합니다.
  for (var index = 0; index < localAssets.length; index += 4) {
    // 직전 묶음을 읽는 사이 게임을 나갔다면 더 이상 context를 사용하지 않습니다.
    if (!context.mounted) return;
    final end = (index + 4).clamp(0, localAssets.length);
    await Future.wait(
      localAssets
          .sublist(index, end)
          .map((asset) => precacheRequiredImage(asset.provider(), context)),
    );
  }

  final uniqueCharacterIds = characterIds.toSet();
  if (!context.mounted) return;
  await Future.wait(
    uniqueCharacterIds.map(
      (id) => precacheRequiredImage(
        AssetImage(roomCharacterAssetPath(id)),
        context,
      ),
    ),
  );
}
