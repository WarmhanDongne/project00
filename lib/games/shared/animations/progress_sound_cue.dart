import 'package:flutter/widgets.dart';
import 'package:project00/core/sound/sound_effects.dart';

/// 연출 진행도가 임계값에 닿는 순간 효과음을 정확히 한 번 재생합니다.
///
/// "재생 플래그 + 임계값 비교 + 1회 재생" 코드가 카드 던지기·도장·하트
/// 파열에 각자 복사돼 있던 것을 모았습니다. 애니메이션 리스너나 빌더 안에서
/// [maybePlay]를 매 틱 호출하면 임계값을 처음 넘는 순간에만 소리가 납니다.
class ProgressSoundCue {
  /// 오디오 출력 지연을 감안해 화면 접촉보다 앞서 재생을 요청하는 표준
  /// 선행 시간입니다. 화면(접촉 시점)은 그대로 두고 소리만 앞당기므로,
  /// 아직 늦게 들리면 이 값을 키우고 너무 빠르면 줄이세요.
  static const Duration lead = Duration(milliseconds: 60);

  bool _played = false;

  /// 재접속·화면 재구성 복원처럼 소리 없이 지나가야 할 때 호출합니다.
  void markPlayed() => _played = true;

  /// 연출을 처음부터 다시 재생할 때 호출해 다음 재생을 허용합니다.
  void reset() => _played = false;

  /// [value]가 [threshold] 이상이 되는 첫 호출에서 [asset]을 재생합니다.
  ///
  /// [value]와 [threshold]는 같은 단위(진행도 또는 경과 ms)여야 합니다.
  void maybePlay(
    BuildContext context,
    String asset, {
    required double value,
    required double threshold,
  }) {
    if (_played || value < threshold) return;
    _played = true;
    SoundEffects.play(context, asset);
  }
}
