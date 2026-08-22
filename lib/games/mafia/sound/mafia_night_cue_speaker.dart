import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';

//=======================밤 행동 소리 신호 → 소리==============================
/// 서버가 올린 밤 행동 신호를 **낼 소리로** 옮깁니다.
///
/// 확정(2026-08): 총성 같은 직업 효과음은 밤이 시작될 때 자동으로 울리지 않고,
/// 그 직업이 **선택을 완료한 순간** 방 가운데 태블릿에서 울립니다.
///
/// 태블릿 화면에서 떼어 둔 이유는 지켜야 할 규칙이 세 가지나 되기 때문입니다.
///
/// 1. **같은 신호로 두 번 울리지 않습니다.** 서버 상태는 다른 이유로도 계속
///    바뀝니다(타이머·인원수). 그때마다 총이 울리면 방이 난장판이 됩니다.
/// 2. **붙는 순간의 신호는 울리지 않습니다.** 재접속하면 이미 지나간 선택의
///    신호가 남아 있는데, 그 총성이 뒤늦게 울리면 안 됩니다.
/// 3. 신호가 없던 상태에서 **첫 신호가 오면 울립니다.** (신호 없이 붙은 것과
///    이미 신호가 있는 상태로 붙은 것을 구분해야 합니다 — 여기서 한 번
///    틀렸습니다.)
class MafiaNightCueSpeaker {
  /// 마지막으로 처리한 신호 번호입니다. 0은 '아직 신호 없음'입니다.
  int _handledId = 0;

  /// 서버 상태를 한 번이라도 받았는지입니다.
  bool _synced = false;

  /// [cue]를 받고 지금 낼 소리입니다. 낼 것이 없으면 null입니다.
  ///
  /// 상태가 올 때마다 부르세요. 부르는 것만으로 신호를 처리한 것으로
  /// 기록하므로, 반환값이 null이어도 다음에 같은 신호로 울리지 않습니다.
  String? soundFor(MafiaNightActionCue? cue) {
    final id = cue?.id ?? 0;
    final wasSynced = _synced;
    _synced = true;

    if (id == _handledId) return null;
    _handledId = id;

    // 붙는 순간에 이미 있던 신호는 지나간 일입니다.
    if (!wasSynced) return null;
    // 게임이 새로 시작되면 신호가 지워집니다(울릴 것이 없습니다).
    if (cue == null) return null;

    // 아직 소리 파일이 없는 행동은 조용히 지나갑니다.
    return MafiaSounds.nightActionSound(cue.action);
  }
}
