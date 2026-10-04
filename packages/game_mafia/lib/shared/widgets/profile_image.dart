// [profile_image.dart] 는 마피아에서 사용하는 플레이어 프로필 사진을 그리는 파일이다.
//
// - [Package] : 마피아
// - [SharedWidget] : 휴대폰과 태블릿이 함께 쓰는 프로필 사진 표시
//
// 즉, 두 기기가 같은 규칙으로 사진과 대체 이미지를 그리기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/gen/assets.gen.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 프로필 사진
// ---------------------------------------------------------------------------
// 휴대폰(지목·투표·처형 공개)과 태블릿(처형 공개·개표)이 같은 그림을 씁니다.
// 그래서 phone/ 이 아니라 shared/ 에 둡니다 — 한쪽을 정리할 때 다른 쪽이
// 깨지지 않게 하는 것이 이 자리의 목적입니다.

/// 게임에서 사용하는 플레이어 동물 캐릭터입니다.
///
/// 로비 프로필 URL은 받더라도 사용하지 않습니다. 게임 도중 네트워크 이미지가
/// 늦게 뜨거나 서로 다른 사진 규칙이 섞이지 않도록, 모든 마피아 화면은 로비에서
/// 선택한 동물 캐릭터만 동일하게 표시합니다.
class MafiaProfileImage extends StatelessWidget {
  const MafiaProfileImage({super.key, required this.url, this.characterId});

  /// 이전 호출부와 생성자 계약을 유지하기 위한 값입니다. 게임 화면에서는
  /// 의도적으로 읽지 않고 [characterId]만 사용합니다.
  final String url;

  /// 로비에서 고른 동물 아이콘 id입니다.
  ///
  /// 사진을 올리지 않은 사람은 이 아이콘으로 보입니다. 이 값을 넘기지 않아
  /// 마피아 화면에서만 카드 뒷면이 나왔습니다(2026-08).
  final String? characterId;

  @override
  Widget build(BuildContext context) {
    return _buildCharacter();
  }

  Widget _buildCharacter() {
    final id = characterId?.trim() ?? '';
    if (id.isEmpty) return _buildCardBack();

    // 첫 디코딩 프레임 전에도 빈 칸이 생기지 않도록 카드 뒷면을 먼저 깔고
    // 동물 캐릭터를 그 위에 올립니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCardBack(),
        Image.asset(
          roomCharacterAssetPath(id),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCardBack() =>
      Assets.games.mafia.images.cards.roleBack.game.image(fit: BoxFit.cover);
}
