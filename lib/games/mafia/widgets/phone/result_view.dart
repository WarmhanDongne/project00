import 'package:flutter/material.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';

//=======================P9 결과 화면==============================
/// 게임 결과 화면입니다(시안 `phone-p9`).
///
/// 시안은 **화면 전체를 덮는 승리 포스터 한 장**입니다. 문구도 버튼도 없습니다.
/// 다시하기·홈으로 버튼은 시안상 **태블릿에만** 있고, 이는 의도된 것으로
/// 확인되었습니다. 태블릿이 공용 결과 화면입니다.
///
/// 포스터는 승리 진영으로 고릅니다([MafiaResultArt]). 중립 역할이 개별 조건으로
/// 이기는 경우(광대·처형자·생존자 등)에는 전용 포스터가 없으므로 승리 문구를
/// 대신 보여 줍니다. 결과 화면이 빈 화면으로 남는 것보다 낫기 때문입니다.
class MafiaResultView extends StatelessWidget {
  const MafiaResultView({
    super.key,
    required this.winner,
    this.winnerRoleIds = const {},
    this.winnerLabel,
  });

  /// 승리 진영입니다. 서버가 보낸 값을 그대로 씁니다.
  ///
  /// 중립 역할의 개별 승리처럼 진영으로 환원되지 않으면 null입니다.
  final MafiaFaction? winner;

  /// 승리 문구를 덮어쓸 때 씁니다.
  ///
  /// 중립 승리는 진영 이름이 아니라 역할 이름을 보여 주는 편이 분명하므로
  /// (예: `광대 승리`) 호출부가 서버 문구를 그대로 넘길 수 있게 열어 둡니다.
  /// 이긴 사람들의 역할 id입니다. 중립 포스터를 고르는 데 씁니다.
  final Set<String> winnerRoleIds;

  final String? winnerLabel;

  @override
  Widget build(BuildContext context) {
    final poster = MafiaResultArt.phonePoster(
      winner,
      winnerRoleIds: winnerRoleIds,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);

        if (poster != null) {
          // 시안은 프레임(402)보다 넓은 그림(492)을 가로 중앙에서 잘라 씁니다.
          return poster.image(
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 27 * scale),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    winnerLabel ?? MafiaResultArt.label(winner),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MafiaResultArt.color(winner),
                      fontSize: 48 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
