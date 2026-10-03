import 'package:game_mafia/shared/models/game_rules.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/shared/models/role.dart';

// [game_copy.dart] 는 마피아에서 사용하는 게임 화면에서 사용하는 문구를 한곳에 모아둔 파일이다.
//
// - [Package] : 마피아
// - [Copy] : 게임 화면에서 사용하는 문구를 한곳에 모아둔
//
// 즉, 화면별 문구를 일관되게 관리하고 수정하기 위해 필요한 파일이다.

// ---------------------------------------------------------------------------
// 마피아 사용자 문구
// ---------------------------------------------------------------------------
/// 화면에 보이는 문구입니다.
///
/// 역할 이름이 문장에 들어가는 곳은 **조사가 이름에 따라 달라지므로** 여기서
/// 만듭니다. 역할이 34개로 늘어나도 문법이 어긋나지 않게 하기 위한 것입니다.
abstract final class MafiaCopy {
  /// 마지막 글자에 받침이 있는지입니다.
  ///
  /// 한글 음절은 `0xAC00 + (초성 × 21 + 중성) × 28 + 종성`으로 만들어집니다.
  /// 종성이 0이면 받침이 없습니다.
  ///
  /// 한글이 아닌 이름(영문·숫자)은 받침이 있는 것으로 봅니다. `이었습니다`가
  /// 어느 쪽에도 크게 어긋나지 않기 때문입니다.
  static bool hasFinalConsonant(String word) {
    if (word.isEmpty) return true;
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return true;
    return (code - 0xAC00) % 28 != 0;
  }

  /// 처형자 발표 화면의 제목입니다. 당사자와 나머지 사람이 다른 문구를 봅니다.
  // ---------------------------------------------------------------------------
  // 단계 안내 문구
  // ---------------------------------------------------------------------------
  // 단계가 바뀔 때 화면 가운데에 잠깐 띄우는 안내입니다(확정 2026-08).
  /// 아침 발표를 시작하며 띄웁니다.
  static const String morningNotice = '아침이 되었습니다';

  /// 사망자 발표가 끝나고 토론 화면으로 넘어가기 전에 띄웁니다.
  static const String discussionNotice = '토론을 시작합니다';

  /// 모두가 신분을 확인한 뒤, 첫 밤으로 넘어가기 전에 띄웁니다.
  static const String gameStartNotice = '게임을 시작하겠습니다';

  /// 토론이 과반수 투표로 끝났을 때 띄웁니다(확정 2026-08).
  static const String discussionSkippedNotice = '토론이 투표로 종료되었습니다';

  /// 밤으로 넘어가기 전에 띄웁니다. 이 안내 뒤에 배경이 밤으로 바뀝니다.
  static const String nightNotice = '밤이 되었습니다';

  static const String executedOtherTitle = '오늘의 처형자';
  static const String executedSelfTitle = '당신은 처형 당했습니다';

  /// 아무도 처형되지 않았을 때의 문구입니다(동표가 무효 처리되는 규칙일 때).
  static const String noExecution = '처형된 사람이 없습니다';

  // ---------------------------------------------------------------------------
  // 두 박자로 나눠 찍는 문구
  // ---------------------------------------------------------------------------
  // 확정(2026-08): 안내 문구는 어몽어스 추방 발표처럼 내려찍고
  // ([MafiaEjectionText]), **너무 긴 문장은 두 박자로 나눠** 띄웁니다.
  // 한 줄로 길게 흐르는 것보다 짧게 두 번 박히는 쪽이 훨씬 세게 읽힙니다.
  //
  // 나누는 자리는 문장마다 손으로 정합니다. 글자수로 기계적으로 자르면
  // '표가 같아 아무도 / 처형되지 않았습니다'처럼 어색한 데서 끊깁니다.
  // 찍는 말투라 마침표는 넣지 않습니다.

  /// 밤 사이 죽은 사람을 알립니다.
  static List<String> deathBeats(String names) => ['$names님은', '밤을 넘기지 못했습니다'];

  /// 아무도 죽지 않은 아침입니다.
  static const List<String> noDeathBeats = ['어제 밤,', '아무도 죽지 않았습니다'];

  /// 처형된 사람을 알립니다.
  static List<String> executedBeats(String nickname) => [
    '$nickname님이',
    '처형되었습니다',
  ];

  /// 기자의 취재가 성공한 아침입니다. 대상의 카드가 뒤집혀 공개됩니다.
  ///
  /// 처형 공개와 **같은 연출**을 씁니다. 다른 점은 그 사람이 죽지 않는다는
  /// 것뿐입니다(확정 2026-08).
  static const List<String> exposureBeats = [
    '기자가 어젯밤에 취재에 성공했습니다',
    '대상의 신분이 공개됩니다',
  ];

  /// 동표로 아무도 처형되지 않았습니다.
  static const List<String> tieBeats = ['표가 같아', '아무도 처형되지 않았습니다'];

  /// 처형된 사람의 신분을 공개합니다. 이 게임에서 가장 센 한 방입니다.
  static List<String> wasRoleBeats(String nickname, String roleName) {
    final suffix = hasFinalConsonant(roleName) ? '이었습니다' : '였습니다';
    return ['$nickname님은', '$roleName$suffix'];
  }

  /// 이 빌드가 모르는 신분일 때입니다.
  ///
  /// 새 역할을 서버가 먼저 배포한 뒤 구버전 앱이 붙는 경우를 막기 위한 것입니다.
  static List<String> unknownRoleBeats(String nickname) => [
    '$nickname님의',
    '신분을 확인할 수 없습니다',
  ];

  // ---------------------------------------------------------------------------
  // 룰 다이얼로그
  // ---------------------------------------------------------------------------
  /// 휴대폰 상단바의 룰(팁) 버튼이 보여 주는 문구입니다.
  ///
  /// 마크다운은 쓸 수 없어 문장만 넣습니다. **확정된 규칙만** 담고, 아직 정해지지
  /// 않은 것(토론 조기 종료 권한 등)은 넣지 않습니다.
  static const phoneRules =
      '밤에는 세 구간으로 나눠 행동하며 같은 구간의 신분들은 함께 선택합니다. 시민은 아무것도 하지 않습니다. '
      '선택한 대상과 조사 결과는 비공개입니다.\n\n'
      '아침이 되면 밤 사이 일어난 일이 발표됩니다.\n\n'
      '낮에는 자유롭게 토론한 뒤 비밀 투표로 한 명을 처형합니다. 표가 같으면 '
      '아무도 처형되지 않습니다.\n\n'
      '처형된 사람의 신분은 모두에게 공개됩니다.\n\n'
      '사망하면 모든 사람의 신분을 볼 수 있습니다. 다른 사람에게 보여주지 마세요.\n\n'
      '마피아·교단·연쇄살인마가 모두 사라지면 시민 팀이 이깁니다. 마피아 진영 수가 나머지 생존자 수 이상이 되면 '
      '마피아 팀이 이깁니다. 교단이나 연쇄살인마가 살아 있으면 아직 끝나지 않습니다.';

  /// 태블릿 룰북 문구입니다. 마크다운을 씁니다.
  static const tabletRulebook = '''
## 진행 순서

**밤** → 아침 발표 → **낮 토론** → 투표 → 개표·처형 발표 → 다시 밤

## 밤

밤은 **세 행동 구간**으로 진행하며 같은 구간의 신분들은 함께 선택합니다. 시민은 아무것도 하지 않습니다.
선택한 대상과 조사 결과는 비공개입니다.

마피아가 여럿이면 **다수결**로 한 명을 지목하고, 표가 갈리면 무작위로 정합니다.

## 낮

자유롭게 토론한 뒤 **비밀 투표**로 한 명을 처형합니다.
표가 같으면 아무도 처형되지 않습니다.

처형된 사람의 신분은 **모두에게 공개**됩니다.

## 사망 후

사망하면 모든 사람의 신분을 볼 수 있습니다. 다른 사람에게 보여주지 마세요.

## 승리 조건

- 마피아·교단·연쇄살인마가 모두 사라지면 **시민 팀** 승리
- 마피아 진영 수가 나머지 생존자 수 이상이 되면 **마피아 팀** 승리
''';
  static String roleRules(MafiaRole role) => switch (role.id) {
    'citizen' => '밤 능력은 없습니다. 토론과 투표로 마피아를 찾아내세요.',
    'police' =>
      '밤마다 한 명을 조사합니다. 모든 행동이 확정되면 진영 판정 결과를 본인만 확인합니다. 마피아 보스는 시민으로 보입니다.',
    'doctor' => '밤마다 한 명을 보호합니다. 자신도 선택할 수 있으며 보호받은 사람은 그날 밤 공격에서 살아남습니다.',
    'bodyguard' => '밤마다 한 명을 보호합니다. 현재 규칙은 의사와 같으며 대신 사망하는 능력은 없습니다.',
    'detective' =>
      '밤마다 한 명을 추적해 그 사람이 최종 선택한 대상을 확인합니다. 선택하지 않았다면 방문 없음으로 표시됩니다.',
    'reporter' => '밤마다 한 명을 취재해 다음 아침 정확한 직업을 전체에 공개합니다. 사용 횟수 제한은 없습니다.',
    'mafia' =>
      '동료를 알고 시작합니다. 밤마다 제거 대상을 골라 마피아의 다수결로 한 명을 공격합니다. 진영 승리는 사망한 동료도 함께 받습니다.',
    'mafia_boss' => '마피아와 함께 공격하고 승리합니다. 경찰의 진영 조사에서는 시민으로 보입니다.',
    'politician' => '낮 지목 투표가 2표로 계산됩니다. 최후 변론 뒤 찬반 투표는 다른 사람과 같은 1표입니다.',
    _ => role.description.replaceAll('\n', ' '),
  };

  static String rulesFor(MafiaRuleState state) {
    final reveal = {
      'role': '정확한 직업',
      'faction': '진영만',
      'hidden': '공개하지 않음',
    }[state.rules.executionReveal];
    final roles = state.composition.keys
        .map(MafiaRoles.find)
        .whereType<MafiaRole>();
    final neutral = <String>[];
    if (state.composition.containsKey('jester')) {
      neutral.add('광대: 자신이 낮 투표로 처형되면 단독 승리');
    }
    if (state.composition.containsKey('executioner')) {
      neutral.add('처형자: 자신이 살아 있을 때 지정 목표가 처형되면 승리');
    }
    if (state.composition.containsKey('serial_killer')) {
      neutral.add('연쇄살인마: 생존자가 연쇄살인마뿐이면 승리');
    }
    if (state.composition.containsKey('cult_leader') ||
        state.composition.containsKey('cultist')) {
      neutral.add('교단: 모든 생존자가 교단이면 승리');
    }
    return [
      '밤 → 아침 → 토론 → 비밀 투표 → 처형 발표',
      '밤에는 세 구간으로 행동합니다. 선택은 한 번 확정하며 조사 결과는 차단 등 판정 후 공개됩니다.',
      '의사는 자신을 보호할 수 있습니다. 마피아는 동료를 공격할 수 없고, 공격 투표 동률은 무작위로 정합니다.',
      '낮의 지목 투표는 최다 득표자를 고릅니다. 동률이면 처형하지 않습니다. 미투표는 기권입니다.',
      state.rules.trial
          ? '후보의 30초 변론 후 찬반 투표를 합니다. 찬반은 1인 1표이며 투표권자 과반수가 찬성해야 처형됩니다.'
          : '최후 변론·찬반 재투표 없이 처형합니다.',
      '처형 신분: $reveal. 기자가 공개한 정보는 유지됩니다.',
      '토론은 생존자 과반수가 종료를 요청하면 일찍 끝납니다.',
      '마피아·연쇄살인마·교단이 모두 없어지면 시민 진영 승리. 교단·연쇄살인마가 없고 마피아 진영이 나머지 생존자 이상이면 마피아 진영 승리.',
      ...neutral,
      '사망자는 누르고 있는 동안만 전원의 역할을 볼 수 있습니다. 주변에 화면을 보여주거나 정보를 알려주지 마세요.',
      if (state.composition.isNotEmpty) '이번 판 역할',
      for (final role in roles)
        '${role.displayName} ${state.composition[role.id]}명: ${roleRules(role)}',
    ].join('\n\n');
  }
}
