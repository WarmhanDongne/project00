import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/service/sound_service.dart';

void main() {
  Duration offset(Duration? total, Duration window) =>
      SoundService.startOffsetFor(total: total, window: window);

  //=======================앞을 자르고 뒤는 남긴다==============================
  // 룰렛 효과음은 멈추는 순간의 소리와 그 여운이 핵심입니다. 연출(4초)에 맞춘다고
  // 뒤를 끊으면 그 부분이 통째로 사라지므로, 앞을 건너뛰어 끝을 맞춥니다.
  test('파일이 길면 남은 길이가 연출 길이와 같아지는 지점에서 시작한다', () {
    expect(
      offset(const Duration(seconds: 34), const Duration(seconds: 4)),
      const Duration(seconds: 30),
    );
  });

  test('건너뛴 뒤 남는 길이는 항상 연출 길이와 같다', () {
    const total = Duration(milliseconds: 17400);
    const window = Duration(seconds: 4);
    expect(total - offset(total, window), window);
  });

  test('파일이 연출보다 짧으면 처음부터 재생한다', () {
    expect(
      offset(const Duration(seconds: 2), const Duration(seconds: 4)),
      Duration.zero,
    );
  });

  test('길이가 같으면 처음부터 재생한다', () {
    expect(
      offset(const Duration(seconds: 4), const Duration(seconds: 4)),
      Duration.zero,
    );
  });

  // 소스가 아직 준비되지 않으면 getDuration이 null을 줍니다. 그때 잘못 계산해
  // 앞을 건너뛰면 소리가 아예 안 납니다.
  test('길이를 알 수 없으면 처음부터 재생한다', () {
    expect(offset(null, const Duration(seconds: 4)), Duration.zero);
  });
}
