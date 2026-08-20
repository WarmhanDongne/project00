import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/liars_poker/sound/liars_poker_sounds.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/core/assets/game_image.dart';

/// Liar's Poker 로딩 화면에 표시할 전략 팁입니다.
///
/// 실제 규칙과 어긋나면 안내가 아니라 혼란이 되므로, 규칙이 바뀌면 태블릿
/// 룰북(`widgets/tablet/rolebook.dart`)과 함께 고칩니다.
const liarsPokerLoadingTips = <String>[
  '기준 카드는 라운드마다 바뀝니다. 새 라운드가 시작되면 먼저 확인하세요.',
  '조커는 어떤 기준 카드로든 인정됩니다. 아껴 두면 위기에서 진실이 됩니다.',
  '한 번에 3장까지 낼 수 있습니다. 많이 낼수록 들켰을 때 잃는 것도 커집니다.',
  '룰렛에서 살아남아도 다음 룰렛은 더 불리해집니다. 두 번은 피하세요.',
  '세 번째 룰렛은 12칸 중 11칸이 탈락입니다. 그 전에 승부를 보세요.',
  'LIAR는 확신이 들 때만 외치세요. 틀리면 내가 룰렛을 돌립니다.',
  '내가 기준 카드를 많이 들고 있다면, 상대의 주장은 거짓일 확률이 높습니다.',
  '상대가 낸 장수를 세어 두면 손패가 언제 바닥나는지 보입니다.',
  '카드가 남은 사람이 나 혼자가 되면 FOLD로 의심을 접을 수 있습니다.',
  '남은 사람이 둘뿐일 때 LIAR 판정에 실패하면 룰렛이 한 단계 불리해집니다.',
  '망설임 없이 바로 낸 카드가 언제나 진실은 아닙니다.',
  '같은 방식으로만 속이면 패턴이 읽힙니다. 진실도 섞어 내세요.',
  '상대가 나를 정직한 사람으로 여기게 만들면 결정적인 순간에 통합니다.',
  '손패를 먼저 비워도 승리가 아닙니다. 마지막까지 살아남아야 이깁니다.',
];

/// 게임 화면에서 최초 표시될 로컬 이미지와 참가자 프로필을 미리 디코딩합니다.
///
/// 프로필 하나의 실패는 게임 입장을 막지 않습니다. 해당 URL은 실제 화면에서
/// 기본 프로필로 대체할 수 있도록 나머지 준비 작업과 분리해 처리합니다.
Future<void> preloadLiarsPokerAssets(
  BuildContext context, {
  required bool isPhone,
  required Iterable<String> profileImageUrls,
}) async {
  // 서버 에셋 도입 대비 훅입니다. 지금은 아무것도 하지 않지만, 도입 후에는
  // 여기서 게임 리소스 버전 검사와 다운로드가 일어납니다. 실패해도 번들
  // 폴백으로 진행하므로 게임 진입을 막지 않습니다.
  try {
    await GameAssetStore.instance.prepareGame('liars_poker');
  } catch (_) {}

  // 첫 카드 제출·공개 소리가 늦지 않도록 게임 전용 효과음을 먼저 준비합니다.
  unawaited(
    SoundEffects.of(context)?.preloadEffects(LiarsPokerSounds.preloadTargets) ??
        Future<void>.value(),
  );

  final images = Assets.games.liarsPoker.images;
  final localAssets = <GameImage>[
    // Liar's Poker 휴대폰은 세로·가로 회전을 모두 허용합니다. 현재 방향의
    // 배경만 준비하면 관전 진입이나 회전 시 반대 방향 배경을 처음 디코딩하며
    // 한 프레임 번쩍일 수 있으므로 휴대폰에서는 두 배경을 모두 준비합니다.
    if (isPhone) ...[
      images.background.backgroundPhone.game,
      images.background.background.game,
    ] else
      images.background.background.game,
    images.background.a.game,
    images.background.k.game,
    images.background.q.game,
    ...images.cards.values.game,
    ...images.button.values.game,
    ...images.icons.values.game,
    ...images.modal.values.game,
    ...images.other.values.game,
    images.table.tableAceWhite.game,
    images.table.tableKingWhite.game,
    images.table.tableQueenWhite.game,
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

  final uniqueProfileUrls = profileImageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toSet();
  await Future.wait(
    uniqueProfileUrls.map((url) async {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (_) {
        // 프로필 서버가 일시적으로 실패해도 게임 자체는 기본 이미지로 진행합니다.
      }
    }),
  );
}
