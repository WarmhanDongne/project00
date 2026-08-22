import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';

/// 마피아 전용 효과음 경로입니다.
///
/// 여러 게임이 함께 쓰는 소리(카드 분배·룰렛 등)는
/// `core/sound/app_sounds.dart`에 있습니다. 여기에는 마피아만 쓰는 것만 둡니다.
abstract final class MafiaSounds {
  /// 총성입니다.
  ///
  /// 확정(2026-08): **마피아가 제거 대상 선택을 완료한 순간** 태블릿에서
  /// 울립니다. 밤이 시작될 때 자동으로 울리던 것을 바꿨습니다 — 아무도
  /// 고르지 않았는데 총이 울리면 연출이 겉돕니다.
  static const gunshot = 'assets/games/mafia/sounds/gun.mp3';

  //=======================직업별 밤 행동 소리==============================
  /// 밤 행동이 제출된 순간 낼 소리입니다. 파일이 없는 행동은 null입니다.
  ///
  /// [action]은 서버가 보내는 행동 종류(`MafiaNightActionCue.action`)입니다.
  /// 역할 이름이 아니라 **행동 종류**로 갈라 쓰므로, 같은 행동을 쓰는 역할이
  /// 추가돼도 이 표는 고칠 필요가 없습니다.
  ///
  /// ⚠️ 아직 파일이 없어 소리가 나지 않는 행동들입니다. 파일이 들어오면 상수를
  /// 하나 추가하고 이 표에 한 줄 넣으면 그 순간부터 울립니다.
  ///
  /// | 행동 | 역할 | 어울리는 소리 |
  /// |---|---|---|
  /// | `protect` | 의사·경호원 | 심장 박동 한 번, 또는 방패가 닫히는 소리 |
  /// | `investigate` | 경찰 | 손전등을 켜는 딸깍 소리 |
  /// | `investigateRole` | 정보원 | 서류를 넘기는 소리 |
  /// | `roleblock` | 역할 차단자 | 문이 잠기는 소리 |
  /// | `convert` | 교주·뱀파이어 | 낮게 속삭이는 소리 |
  /// | `silence` | 침묵술사 | 숨을 삼키는 소리 |
  /// | `track`·`watch` | 사립탐정·감시자 | 발소리 한 걸음 |
  /// | `steal` | 도둑 | 자물쇠를 따는 소리 |
  ///
  /// ⚠️ `eliminate`는 마피아뿐 아니라 자경단원·짐승인간·연쇄살인마도 씁니다.
  /// 그 밤에 총성이 두 번 울릴 수 있는데, 규칙상 실제로 공격자가 둘이라는
  /// 뜻이므로 그대로 둡니다.
  static String? nightActionSound(String action) => switch (action) {
    'eliminate' => gunshot,
    _ => null,
  };

  //=======================나레이션(사람 목소리)==============================
  // 받은 파일(2026-08-22 Take4)입니다. 효과음과 달리 **한 판에 한 번**만 나고,
  // 방 가운데 태블릿에서만 냅니다. 여러 기기가 함께 울리면 말이 겹쳐 들립니다.

  /// '밤이 되었습니다' 안내가 뜨는 순간 재생합니다(1.4초).
  static const voiceNight = 'assets/games/mafia/sounds/voice_night.m4a';

  /// 시민 팀 승리 발표에 재생합니다(1.6초).
  static const voiceWinCitizen =
      'assets/games/mafia/sounds/voice_win_citizen.m4a';

  /// 마피아 팀 승리 발표에 재생합니다(1.7초).
  static const voiceWinMafia = 'assets/games/mafia/sounds/voice_win_mafia.m4a';

  /// 이긴 진영에 맞는 나레이션입니다. 중립 개별 승리는 아직 파일이 없어 null입니다.
  static String? winVoiceFor(MafiaFaction? winner) => switch (winner) {
    MafiaFaction.citizen => voiceWinCitizen,
    MafiaFaction.mafia => voiceWinMafia,
    _ => null,
  };

  /// 밤에 멀리서 들리는 늑대 하울링입니다.
  ///
  /// 확정(2026-08): 밤이 시작되고 10초가 지난 뒤부터 **밤 한 번에 한 번**,
  /// 무작위 시각에 태블릿에서 울립니다. 정해진 시각에 울리면 몇 판만 해도
  /// 박자가 읽혀 분위기가 죽습니다.
  ///
  /// 연출과 맞출 필요가 없는 배경 소리라 [preloadTargets]에 넣지 않습니다
  /// (파일이 6초로 길어 미리 물려 두면 메모리만 씁니다).
  static const wolfHowl = 'assets/games/mafia/sounds/wolf_howl.mp3';

  /// 투표를 제출했을 때 재생합니다.
  static const vote = 'assets/games/mafia/sounds/vote.mp3';

  /// 마피아 승리 결과 화면에서 재생합니다.
  ///
  /// 시민 승리용 소리는 아직 없습니다. 파일이 들어오면 여기에 추가하고
  /// 결과 화면에서 승리 진영으로 갈라 쓰면 됩니다.
  static const mafiaWin = 'assets/games/mafia/sounds/win_mafia.mp3';

  /// 낮 동안 깔리던 배경음악입니다. **지금은 쓰지 않습니다.**
  ///
  /// 확정(2026-08): 낮에는 배경음악을 깔지 않습니다. 사람들이 서로 이야기하는
  /// 시간이라 곡이 목소리를 덮고, 조용한 낮과 곡이 깔린 밤이 갈려야 밤이
  /// 밤답게 느껴집니다. 되살리려면 `mafiaBackgroundMusicFor`가 이 값을
  /// 돌려주게만 하면 됩니다(화면 코드는 고칠 필요 없습니다).
  ///
  /// 효과음이 아니라 **BGM 채널**로 재생합니다
  /// (`shared/sound/game_background_music.dart`). 반복 재생이므로 화면을 떠날 때
  /// 반드시 멈춰야 합니다. 그래서 [preloadTargets]에 넣지 않습니다.
  ///
  /// ⚠️ 지금은 공용 곡과 같은 파일이라 임시로 공용 상수를 참조합니다(용량
  /// 절약). 마피아 전용 낮 곡이 들어오면 파일을 넣고 이 상수만 바꾸세요.
  static const background = AppSounds.background;

  /// 밤 동안 깔리는 배경음악입니다. 마피아에서 유일하게 깔리는 곡입니다.
  ///
  /// 아침이 되면 `GameBackgroundMusic.fadeOut()`으로 서서히 사라집니다.
  static const nightBackground =
      'assets/games/mafia/sounds/background/background_night.m4a';

  /// 게임 진입 준비 단계에서 미리 풀어 둘 짧은 효과음입니다.
  ///
  /// 준비하지 않으면 첫 재생에서 에셋을 파일로 풀어내며 소리가 화면보다 늦게
  /// 납니다. 총성·승리음은 게임에 한 번만 나므로 매번 그 지연을 겪습니다.
  /// 여러 사람이 동시에 눌러 겹쳐 날 수 있는 짧은 소리입니다. 사본을 여러 개
  /// 물려 둡니다.
  static const preloadTargets = [gunshot, vote, mafiaWin];

  /// 한 번에 하나만 나는 안내 음성입니다. **[preloadTargets]와 나눠 둡니다** —
  /// 겹칠 일이 없어 사본 하나로 충분하고, 사본을 아껴야 기기 디코더가 모자라
  /// 준비가 실패하는 일이 없습니다(2026-08 iOS 사고).
  static const narrationTargets = [voiceNight, voiceWinCitizen, voiceWinMafia];
}
