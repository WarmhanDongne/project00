import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';

//=======================휴대폰 내용 가운데 맞춤==============================
// 확정(2026-08): 화면별 내용(격자·대기 문구)은 상단 안내와 하단 버튼 사이
// '내용 띠' 가운데에 옵니다. 인원이 적어도 위쪽으로 치우치지 않습니다.
void main() {
  double gridCenter(int players) {
    final spec = MafiaTileGridSpec.of(players);
    final height = spec.cellHeight * spec.rowsFor(players);
    return MafiaPlayerSelectGrid.topFor(players) + height / 2;
  }

  test('격자는 인원이 적어도 내용 띠 가운데에 온다', () {
    for (final players in [2, 3, 4, 6]) {
      expect(
        gridCenter(players),
        closeTo(MafiaPhoneDesign.contentBandCenter, 0.5),
        reason: '$players명 격자가 가운데에 없습니다',
      );
    }
  });

  test('격자가 길어지면 띠 위쪽까지만 올라간다', () {
    // 9명은 3열 3줄로 가장 긴 격자입니다.
    expect(
      MafiaPlayerSelectGrid.topFor(9),
      greaterThanOrEqualTo(MafiaPhoneDesign.contentBandTop),
    );
    // 아래 버튼(652)을 넘지 않아야 합니다.
    final spec = MafiaTileGridSpec.of(9);
    final bottom =
        MafiaPlayerSelectGrid.topFor(9) + spec.cellHeight * spec.rowsFor(9);
    expect(bottom, lessThanOrEqualTo(MafiaPhoneDesign.buttonTop));
  });

  test('대기 문구 묶음도 띠 가운데를 기준으로 놓인다', () {
    // 두 줄(24px + 20px)의 가운데가 띠 가운데 근처여야 합니다.
    final blockTop = MafiaPhoneStatusText.waitingTop;
    final blockBottom =
        MafiaPhoneStatusText.waitingSubTop +
        MafiaPhoneStatusText.waitingSubFontSize;
    expect(
      (blockTop + blockBottom) / 2,
      closeTo(MafiaPhoneDesign.contentBandCenter, 12),
    );
  });
}
