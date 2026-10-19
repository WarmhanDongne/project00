import 'dart:ui';

/// 서버 `functions/src/yut/game.ts`와 같은 29칸 윷판입니다.
///
/// 0번은 오른쪽 아래 출발 모서리이고 바깥 길은 1–19번을 시계 반대 방향으로
/// 돕니다(모서리 5·10·15). 대각선은 5→20→21→22→23→24→15와
/// 10→25→26→22→27→28→0입니다. 태블릿이 말을 놓기 전에 도착 칸과 지나는 길을
/// 미리 보여 주려고 서버 규칙을 그대로 옮겼습니다.
abstract final class YutBoard {
  static const start = 0;
  static const center = 22;
  static const home = 29;
  static const nodeCount = 29;
  static const corners = {0, 5, 10, 15, 22};

  /// 판 그림 안에서 각 칸의 중심입니다. [lo]·[hi]는 바깥 모서리 칸의 위치이고
  /// 판 그림마다 여백이 달라 값을 받습니다(나무판 0.124, 홀로그램판 0.0813).
  static List<Offset> nodes({required double lo, required double hi}) {
    final step = (hi - lo) / 5;
    Offset lerp(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    final topRight = Offset(hi, lo);
    final topLeft = Offset(lo, lo);
    final bottomLeft = Offset(lo, hi);
    final bottomRight = Offset(hi, hi);
    const mid = Offset(.5, .5);
    return [
      bottomRight,
      for (var k = 1; k <= 4; k++) Offset(hi, hi - step * k),
      topRight,
      for (var k = 1; k <= 4; k++) Offset(hi - step * k, lo),
      topLeft,
      for (var k = 1; k <= 4; k++) Offset(lo, lo + step * k),
      bottomLeft,
      for (var k = 1; k <= 4; k++) Offset(lo + step * k, hi),
      lerp(topRight, mid, 1 / 3),
      lerp(topRight, mid, 2 / 3),
      mid,
      lerp(mid, bottomLeft, 1 / 3),
      lerp(mid, bottomLeft, 2 / 3),
      lerp(topLeft, mid, 1 / 3),
      lerp(topLeft, mid, 2 / 3),
      lerp(mid, bottomRight, 1 / 3),
      lerp(mid, bottomRight, 2 / 3),
    ];
  }

  /// [steps]만큼 움직인 뒤의 전체 경로입니다. 음수는 백도입니다.
  static List<int> advance(List<int> path, int steps) {
    final next = [...path];
    if (steps < 0) {
      if (next.length > 1) {
        next.removeLast();
      } else if (next.isNotEmpty && next.first == start) {
        next[0] = 19;
      } else if (next.length == 1) {
        next[0] = start;
      }
      return next;
    }
    final startNode = next.isEmpty ? null : next.last;
    for (var step = 0; step < steps; step++) {
      if (next.isEmpty) {
        next.add(1);
        continue;
      }
      final position = next.last;
      if (position == home) break;
      final previous = next.length > 1 ? next[next.length - 2] : null;
      next.add(_next(position, previous, step == 0 && position == startNode));
      if (next.last == home) break;
    }
    return next;
  }

  static int _next(int position, int? previous, bool startsHere) =>
      switch (position) {
        0 => home,
        5 => startsHere ? 20 : 6,
        10 => startsHere ? 25 : 11,
        19 => 0,
        20 => 21,
        21 => 22,
        22 => startsHere || previous != 21 ? 27 : 23,
        23 => 24,
        24 => 15,
        25 => 26,
        26 => 22,
        27 => 28,
        28 => 0,
        _ => position + 1,
      };
}

/// 윷 결과 이름입니다. 서버 `YutResultName`과 같은 문자열을 씁니다.
enum YutResult {
  backDo('backDo', -1),
  doo('do', 1),
  gae('gae', 2),
  geol('geol', 3),
  yut('yut', 4),
  mo('mo', 5);

  const YutResult(this.wire, this.steps);
  final String wire;
  final int steps;

  bool get throwsAgain => this == yut || this == mo;

  static YutResult? fromWire(Object? value) {
    for (final result in values) {
      if (result.wire == value) return result;
    }
    return null;
  }
}
