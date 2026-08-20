import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 로딩 화면에 표시할 전략 팁입니다.
const liarsPokerLoadingTips = <String>[
  '항상 진실만 낼 필요는 없습니다. 블러핑도 중요한 전략입니다.',
  '너무 자신감 있는 플레이는 오히려 의심을 살 수 있습니다.',
  '가끔은 약한 패도 강하게 보이는 것이 더 효과적입니다.',
  '상대의 행동과 속도를 함께 관찰해 보세요.',
  '좋은 카드는 너무 빨리 공개하지 않는 것도 전략입니다.',
  '상대의 습관을 기억하면 다음 라운드에 도움이 됩니다.',
  '남은 카드 수를 기억하면 판단이 쉬워집니다.',
  '블러핑은 전략입니다. 하지만 너무 자주 하면 들키기 쉽습니다.',
  '라이어는 확신이 들 때만 외치세요.',
  '상대의 표정보다 플레이 패턴을 읽어보세요.',
  '좋은 카드를 아끼는 것도 하나의 전략입니다.',
  '조커는 판을 뒤집을 수 있는 카드입니다.',
  '침착함은 최고의 무기입니다.',
  '상대가 빠르게 낸 카드가 항상 진실은 아닙니다.',
  '카드를 모두 버리는 것보다 끝까지 살아남는 것이 중요할 수도 있습니다.',
  '한 번의 성공적인 블러핑이 게임의 흐름을 바꿀 수 있습니다.',
  '상대가 당신을 어떻게 생각하는지도 중요한 정보입니다.',
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
  final images = Assets.games.liarsPoker.images;
  final localAssets = <AssetGenImage>[
    // Liar's Poker 휴대폰은 세로·가로 회전을 모두 허용합니다. 현재 방향의
    // 배경만 준비하면 관전 진입이나 회전 시 반대 방향 배경을 처음 디코딩하며
    // 한 프레임 번쩍일 수 있으므로 휴대폰에서는 두 배경을 모두 준비합니다.
    if (isPhone) ...[
      images.background.backgroundPhone,
      images.background.background,
    ] else
      images.background.background,
    images.background.a,
    images.background.k,
    images.background.q,
    ...images.cards.values,
    ...images.button.values,
    ...images.icons.values,
    ...images.modal.values,
    ...images.other.values,
    images.table.tableAceWhite,
    images.table.tableKingWhite,
    images.table.tableQueenWhite,
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
