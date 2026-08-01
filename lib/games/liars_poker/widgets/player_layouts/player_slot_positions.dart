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

/// 중심 좌표를 `player_layouts`에서 사용하는 슬롯 좌측 상단 좌표로 변환합니다.
List<Offset> normalizedPlayerSlotTopLeftPositions({
  required int playerCount,
  required Size boardSize,
  double slotSize = 160,
}) {
  final centers = playerCentersForBoard(
    playerCount: playerCount,
    boardSize: boardSize,
  );

  return centers
      .map(
        (center) => Offset(
          (center.dx - slotSize / 2) / boardSize.width,
          (center.dy - slotSize / 2) / boardSize.height,
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
