import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_composition.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';

/// 선택 그리드가 하단 버튼을 덮지 않는지 지키는 가드입니다.
///
/// 시안은 3열까지만 그려져 있습니다. 3열로 10인을 담으면 4행이 되어 그리드가
/// 버튼 자리(top 652)까지 내려오므로, **10인부터는 4열로 바꾸고 프로필·닉네임을
/// 줄입니다.**
///
/// 구성표에 있는 **모든 인원(4~12)**을 확인합니다. 아직 역할 구현이 끝나지 않아
/// 실제로 플레이할 수 있는 인원은 더 적지만, 나중에 12인을 켤 때 화면이 조용히
/// 깨지지 않도록 미리 막아 둡니다.
void main() {
  test('구성표의 모든 인원에서 그리드가 하단 버튼을 덮지 않는다', () {
    for (final count in MafiaComposition.recommended.keys) {
      expect(
        MafiaPlayerSelectGrid.designBottom(count),
        lessThanOrEqualTo(MafiaPhoneDesign.buttonTop),
        reason: '$count인에서 그리드가 버튼을 덮습니다.',
      );
    }
  });

  test('9인까지는 3열, 10인부터는 4열이다', () {
    for (final count in [4, 6, 9]) {
      expect(MafiaPlayerSelectGrid.columnsFor(count), 3, reason: '$count인');
    }
    for (final count in [10, 11, 12]) {
      expect(MafiaPlayerSelectGrid.columnsFor(count), 4, reason: '$count인');
    }
  });

  test('두 규격의 좌우 여백이 같아 화면 정렬이 흔들리지 않는다', () {
    // 시안 폭 402에서 좌우 여백 52 → 그리드 폭 298 + 52 * 2 = 402.
    expect(MafiaPlayerSelectGrid.gridSize(9).width, 402);
    expect(MafiaPlayerSelectGrid.gridSize(12).width, 402);
  });

  test('12인은 4열 3행으로 들어간다', () {
    final size = MafiaPlayerSelectGrid.gridSize(12);
    // 4열 규격의 한 칸 높이 88 × 3행.
    expect(size.height, 88 * 3);
    expect(MafiaPlayerSelectGrid.designBottom(12), 226 + 264);
  });
}
