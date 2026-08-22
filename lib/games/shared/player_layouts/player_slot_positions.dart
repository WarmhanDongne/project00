import 'dart:math' as math;
import 'package:flutter/widgets.dart';

//사용 방법
//normalizedPlayerCenters(playerCount)

//용도 숫자에 따라서 사용자 위치를 계산해주는 함수

const double defaultPlayerRingRadiusX = 0.34;
const double defaultPlayerRingRadiusY = 0.34;
const double defaultPlayerOrbitRadiusFactor = 0.395;

double _startAngleForPlayerCount(int playerCount) {
  return switch (playerCount) {
    2 => math.pi,
    4 => -math.pi * 0.75,
    _ => -math.pi / 2,
  };
}

/// 중앙 테이블을 기준으로 동일한 간격으로 배치된 플레이어 중심 정규화 좌표입니다.
///
/// 카드 분배, 잔여 카드 표시, 자리 설정 화면이 모두 이 좌표를 공유합니다.
List<Offset> normalizedPlayerCenters(int playerCount) {
  assert(playerCount > 0);

  final startAngle = _startAngleForPlayerCount(playerCount);

  return List<Offset>.generate(playerCount, (index) {
    final angle = startAngle + (math.pi * 2 * index / playerCount);
    return Offset(
      0.5 + math.cos(angle) * defaultPlayerRingRadiusX,
      0.5 + math.sin(angle) * defaultPlayerRingRadiusY,
    );
  }, growable: false);
}

/// 화면의 짧은 변을 기준으로 실제 원형 궤도에 배치된 플레이어 중심 좌표입니다.
List<Offset> playerCentersForBoard({
  required int playerCount,
  required Size boardSize,
  double radiusFactor = defaultPlayerOrbitRadiusFactor,
}) {
  assert(playerCount > 0);
  assert(radiusFactor > 0);

  final center = Offset(boardSize.width / 2, boardSize.height / 2);
  final radius = boardSize.shortestSide * radiusFactor;
  final startAngle = _startAngleForPlayerCount(playerCount);

  return List<Offset>.generate(playerCount, (index) {
    final angle = startAngle + (math.pi * 2 * index / playerCount);
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }, growable: false);
}

/// 자리 배치 화면 카드의 좌측 상단 정규화 좌표입니다.
///
/// 카드는 가로가 긴 직사각형이라 가로·세로 크기를 따로 받습니다. 궤도는
/// [normalizedPlayerCenters]와 같은 **타원**입니다. 원형 궤도(=짧은 변 기준)로
/// 두면 가로가 긴 태블릿에서 좌우가 비고 위아래는 좁아져, 12인처럼 카드가
/// 많을 때 서로 겹칩니다.
List<Offset> seatingCardTopLeftPositions({
  required int playerCount,
  required Size boardSize,
  required Size cardSize,
}) {
  return normalizedPlayerCenters(playerCount)
      .map(
        (normalized) => playerCenterFromNormalized(
          normalizedCenter: normalized,
          boardSize: boardSize,
        ),
      )
      .map(
        (center) => Offset(
          (center.dx - cardSize.width / 2) / boardSize.width,
          (center.dy - cardSize.height / 2) / boardSize.height,
        ),
      )
      .toList(growable: false);
}

Offset playerCenterFromNormalized({
  required Offset normalizedCenter,
  required Size boardSize,
}) {
  return Offset(
    normalizedCenter.dx * boardSize.width,
    normalizedCenter.dy * boardSize.height,
  );
}
