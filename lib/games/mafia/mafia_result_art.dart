import 'package:flutter/widgets.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================결과 화면 그림==============================
/// 결과 화면(P9)이 쓰는 그림을 승리 진영으로 골라 줍니다.
///
/// 휴대폰과 태블릿이 **같은 대응을 써야** 두 화면의 결과가 어긋나지 않으므로
/// 여기 한곳에 둡니다.
///
/// 중립 역할은 개별 승리 조건을 가지고(광대·처형자·생존자 등) 전용 그림이
/// 없습니다. 그때는 null을 돌려주고, 화면이 문구로 대신 알립니다.
///
/// 배경 파일 이름의 `sitizen`은 오타가 아니라 **에셋 파일명 그대로**입니다.
/// (배너는 `citizen`으로 되어 있어 둘이 다릅니다)
abstract final class MafiaResultArt {
  /// 휴대폰 결과 포스터입니다. 시안은 이 그림 한 장이 화면 전부입니다.
  static GameImage? phonePoster(MafiaFaction? winner) {
    final background = Assets.games.mafia.images.background;
    return switch (winner) {
      MafiaFaction.mafia => background.backgroundPhoneMafiaWin.game,
      MafiaFaction.citizen => background.backgroundPhoneSitizenWin.game,
      // 중립 승리 포스터는 아직 없습니다.
      MafiaFaction.neutral || null => null,
    };
  }

  /// 태블릿 결과 포스터입니다.
  static GameImage? tabletPoster(MafiaFaction? winner) {
    final background = Assets.games.mafia.images.background;
    return switch (winner) {
      MafiaFaction.mafia => background.backgroundTabletMafiaWin.game,
      MafiaFaction.citizen => background.backgroundTabletSitizenWin.game,
      MafiaFaction.neutral || null => null,
    };
  }

  /// 태블릿 명단 화면 **왼쪽** 배너입니다(승리 진영).
  static GameImage? winnerBanner(MafiaFaction? winner) {
    final banner = Assets.games.mafia.images.banner;
    return switch (winner) {
      MafiaFaction.mafia => banner.bannerMafiaWin.game,
      MafiaFaction.citizen => banner.bannerCitizenWin.game,
      MafiaFaction.neutral || null => null,
    };
  }

  /// 태블릿 명단 화면 **오른쪽** 배너입니다(패배 진영).
  ///
  /// 승리 진영의 반대편이므로 [winner]만 받으면 정해집니다.
  static GameImage? loserBanner(MafiaFaction? winner) {
    final banner = Assets.games.mafia.images.banner;
    return switch (winner) {
      MafiaFaction.mafia => banner.bannerCitizenLose.game,
      MafiaFaction.citizen => banner.bannerMafiaLose.game,
      MafiaFaction.neutral || null => null,
    };
  }

  /// 패배 진영입니다. 명단을 좌우로 나눌 때 씁니다.
  static MafiaFaction? loserOf(MafiaFaction? winner) => switch (winner) {
    MafiaFaction.mafia => MafiaFaction.citizen,
    MafiaFaction.citizen => MafiaFaction.mafia,
    // 중립은 진영 대결이 아니므로 상대 진영이 정해지지 않습니다.
    MafiaFaction.neutral || null => null,
  };

  /// 승리 문구입니다. 포스터가 없을 때 대신 보여 줍니다.
  static String label(MafiaFaction? winner) =>
      winner == null ? '게임 종료' : '${winner.displayName} 승리';

  /// 승리 문구 색입니다.
  static Color color(MafiaFaction? winner) =>
      winner?.color ?? const Color(0xFF212730);
}
