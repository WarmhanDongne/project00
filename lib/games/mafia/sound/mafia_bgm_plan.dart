import 'package:project00/games/mafia/sound/mafia_sounds.dart';

//=======================마피아 배경음악 규칙==============================
/// 지금 깔아야 할 배경음악입니다. 깔지 않아야 하면 null입니다.
///
/// 확정(2026-08): **밤에만** 배경음악이 깔립니다.
///
/// | 단계 | 곡 |
/// |---|---|
/// | 신분 확인·아침·낮 토론·투표·개표 | 없음 |
/// | 밤 | [MafiaSounds.nightBackground] |
/// | 게임 종료 | 없음 |
///
/// 낮은 사람들이 서로 이야기하는 시간입니다. 곡이 깔려 있으면 목소리를 덮고,
/// 조용한 낮과 곡이 깔린 밤이 갈려야 밤이 밤답게 느껴집니다.
///
/// 아침이 되어 이 함수가 null을 돌려주면 화면은 곧바로 끊지 않고 **서서히
/// 줄이며** 멈춥니다(`GameBackgroundMusic.fadeOut`).
///
/// 낮 곡을 되살리려면 여기서 [MafiaSounds.background]를 돌려주면 됩니다.
/// 화면 코드는 고칠 필요가 없습니다.
String? mafiaBackgroundMusicFor({
  required bool isNight,
  required bool isFinished,
}) {
  if (isFinished) return null;
  return isNight ? MafiaSounds.nightBackground : null;
}

/// 아침이 될 때 밤 곡이 사라지는 데 걸리는 시간입니다.
///
/// 배경이 낮으로 바뀌는 라디얼 와이프(0.9초)보다 조금 길게 두어, 화면이 밝아진
/// 뒤에도 소리가 여운으로 남게 합니다.
const Duration mafiaBgmFadeOut = Duration(milliseconds: 1600);
