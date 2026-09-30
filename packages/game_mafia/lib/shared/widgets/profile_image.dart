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

/// 프로필 사진입니다. URL이 없거나 실패하면 기본 이미지로 대체합니다.
class MafiaProfileImage extends StatelessWidget {
  const MafiaProfileImage({super.key, required this.url, this.characterId});

  final String url;

  /// 로비에서 고른 동물 아이콘 id입니다.
  ///
  /// 사진을 올리지 않은 사람은 이 아이콘으로 보입니다. 이 값을 넘기지 않아
  /// 마피아 화면에서만 카드 뒷면이 나왔습니다(2026-08).
  final String? characterId;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _buildFallback();

    return Image.network(
      url,
      fit: BoxFit.cover,
      // 프로필 서버가 느리거나 실패해도 게임 진행을 막지 않습니다.
      errorBuilder: (_, _, _) => _buildFallback(),
      gaplessPlayback: true,
    );
  }

  /// 사진이 없을 때 그릴 그림입니다. 로비에서 고른 동물이 있으면 그것을,
  /// 없으면 카드 뒷면을 씁니다.
  Widget _buildFallback() {
    final id = characterId?.trim() ?? '';
    if (id.isNotEmpty) {
      return Image.asset(
        roomCharacterAssetPath(id),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildCardBack(),
      );
    }
    return _buildCardBack();
  }

  Widget _buildCardBack() =>
      Assets.games.mafia.images.cards.roleBack.game.image(fit: BoxFit.cover);
}
