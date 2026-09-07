/// 앱 버전 문자열 비교 도구입니다.
///
/// 스토어에 배포된 구버전 앱은 나중에 Firestore에 추가된 게임을 모릅니다.
/// 게임 문서의 `minAppVersion`과 현재 빌드 버전을 비교해, 실행할 수 없는
/// 게임은 시작 대신 업데이트 안내를 보여줍니다.
library;

/// `1.2.3` 형태의 버전 문자열을 비교합니다.
///
/// 반환값은 [Comparable.compareTo]와 같습니다(왼쪽이 낮으면 음수).
/// 숫자가 아닌 조각과 빈 문자열은 0으로 취급해, 서버에 값이 없거나 잘못
/// 입력돼도 게임이 잠기지 않습니다.
int compareAppVersions(String left, String right) {
  final leftParts = _parse(left);
  final rightParts = _parse(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index += 1) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    if (leftValue != rightValue) return leftValue.compareTo(rightValue);
  }
  return 0;
}

/// [current]가 [minimum] 이상인지 확인합니다. [minimum]이 비어 있으면 통과.
bool isAppVersionAtLeast({required String current, required String minimum}) {
  if (minimum.trim().isEmpty) return true;
  return compareAppVersions(current, minimum) >= 0;
}

List<int> _parse(String version) {
  // `1.0.0+12`의 빌드 번호는 스토어 버전 비교에 쓰지 않습니다.
  final plain = version.split('+').first.trim();
  if (plain.isEmpty) return const [0];
  return plain
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList(growable: false);
}
