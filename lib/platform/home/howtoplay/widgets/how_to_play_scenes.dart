import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/platform/home/howtoplay/models/how_to_play_step.dart';
import 'package:project00/platform/home/howtoplay/widgets/how_to_play_pieces.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

//=======================플레이 방식 안내 연출==============================
// 네 장면 모두 0~1로 반복되는 하나의 진행도([t])만 받아 그립니다. 화면 크기가
// 달라도 같은 그림이 나오도록 4:3 판 안에서 정규화 좌표로 배치합니다.

/// 안내 예시에 등장하는 참여자 캐릭터입니다.
const _characterIds = <String>['frog', 'rabbit', 'bear', 'penguin', 'cat'];

/// 안내에 보여 주는 예시 참여 코드입니다.
const _sampleRoomCode = 'QRTEQ';

class HowToPlaySceneView extends StatelessWidget {
  const HowToPlaySceneView({super.key, required this.scene, required this.t});

  final HowToPlayScene scene;

  /// 0~1을 반복하는 장면 진행도입니다.
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 세로로 긴 휴대폰에서는 판을 정사각형에 가깝게 잡아야 그림이 커집니다.
        // 가로로 넓은 태블릿에서는 4:3까지만 넓힙니다.
        final available = constraints.maxHeight <= 0
            ? 4 / 3
            : constraints.maxWidth / constraints.maxHeight;
        return Center(
          child: AspectRatio(
            aspectRatio: available.clamp(1.0, 4 / 3),
            child: switch (scene) {
              HowToPlayScene.placeTablet => _PlaceTabletScene(t: t),
              HowToPlayScene.joinRoom => _JoinRoomScene(t: t),
              HowToPlayScene.takeSeats => _TakeSeatsScene(t: t),
              HowToPlayScene.play => _PlayScene(t: t),
            },
          ),
        );
      },
    );
  }
}

//=======================01 태블릿 놓기==============================
class _PlaceTabletScene extends StatelessWidget {
  const _PlaceTabletScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = Size(constraints.maxWidth, constraints.maxHeight);
        final unit = board.shortestSide;

        final tableIn = segment(t, 0.0, 0.3, curve: Curves.easeOutCubic);
        // 태블릿이 위에서 내려와 테이블 가운데에 놓이고, 닿는 순간 살짝
        // 눌렸다가 펴지면서 화면에 불이 들어옵니다.
        final fall = segment(t, 0.16, 0.56, curve: Curves.easeInCubic);
        final land = segment(t, 0.54, 0.74, curve: Curves.easeOut);
        final ripple = segment(t, 0.56, 0.96, curve: Curves.easeOut);
        final labelIn = segment(t, 0.66, 0.84, curve: Curves.easeOut);

        final tabletCenter = Offset(0.5, 0.10 + (0.52 - 0.10) * fall);
        final tabletScale = 0.66 + 0.34 * fall;
        final squash = math.sin(math.pi * land) * 0.09;
        final tilt = (1 - fall) * -0.18;

        return Stack(
          children: [
            placeAt(
              board: board,
              center: const Offset(0.5, 0.52),
              child: GuideTable(
                size: Size(board.width * 0.8, board.height * 0.54),
                progress: tableIn,
              ),
            ),
            // 태블릿이 테이블에 닿을 때 퍼지는 파장입니다.
            if (ripple > 0 && ripple < 1)
              placeAt(
                board: board,
                center: const Offset(0.5, 0.52),
                child: Container(
                  width: unit * (0.25 + 0.75 * ripple),
                  height: unit * (0.25 + 0.75 * ripple) * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(unit),
                    border: Border.all(
                      color: colors.primary.withValues(
                        alpha: 0.55 * (1 - ripple),
                      ),
                      width: 2,
                    ),
                  ),
                ),
              ),
            // 태블릿이 가까워질수록 진해지는 그림자입니다.
            placeAt(
              board: board,
              center: const Offset(0.5, 0.62),
              child: Container(
                width: unit * 0.42 * (0.7 + 0.3 * fall),
                height: unit * 0.06,
                decoration: BoxDecoration(
                  color: colors.text.withValues(alpha: 0.05 + 0.07 * fall),
                  borderRadius: BorderRadius.circular(unit),
                ),
              ),
            ),
            placeAt(
              board: board,
              center: tabletCenter,
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scaleX: tabletScale * (1 + squash),
                  scaleY: tabletScale * (1 - squash),
                  child: GuideTablet(
                    width: unit * 0.46,
                    glow: land,
                    child: _TabletHomeScreen(unit: unit, awake: land),
                  ),
                ),
              ),
            ),
            placeLabel(
              center: const Offset(0.5, 0.93),
              child: Opacity(
                opacity: labelIn,
                child: Transform.translate(
                  offset: Offset(0, unit * 0.04 * (1 - labelIn)),
                  child: GuideCallout(
                    label: '가로로 눕혀 테이블 한가운데에',
                    fontSize: unit * 0.038,
                    icon: Icons.tablet_mac,
                    emphasized: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 태블릿에 켜지는 홈 화면입니다(로고와 게임판 자리).
class _TabletHomeScreen extends StatelessWidget {
  const _TabletHomeScreen({required this.unit, required this.awake});

  final double unit;
  final double awake;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Opacity(
      opacity: awake,
      child: GuideScreenFit(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '모시겜',
              style: TextStyle(
                color: colors.primary,
                fontSize: unit * 0.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: unit * 0.015),
            Container(
              width: unit * 0.24,
              height: unit * 0.012,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(unit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//=======================02 참여 코드로 입장==============================
class _JoinRoomScene extends StatelessWidget {
  const _JoinRoomScene({required this.t});

  final double t;

  /// 휴대폰 네 대가 서 있는 자리입니다(테이블 바깥 좌우).
  static const _phoneSpots = <Offset>[
    Offset(0.1, 0.28),
    Offset(0.9, 0.28),
    Offset(0.1, 0.74),
    Offset(0.9, 0.74),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = Size(constraints.maxWidth, constraints.maxHeight);
        final unit = board.shortestSide;
        const center = Offset(0.5, 0.5);

        return Stack(
          children: [
            placeAt(
              board: board,
              center: const Offset(0.5, 0.52),
              child: GuideTable(
                size: Size(board.width * 0.52, board.height * 0.5),
              ),
            ),
            placeAt(
              board: board,
              center: center,
              child: GuideTablet(
                width: unit * 0.42,
                child: _TabletCodeScreen(unit: unit),
              ),
            ),
            for (var index = 0; index < _phoneSpots.length; index++) ...[
              // 휴대폰이 하나씩 나타나고, 태블릿의 코드가 날아가 입장이
              // 끝나면 화면이 체크 표시로 바뀝니다.
              ..._buildPhone(context, board, unit, index),
            ],
            placeLabel(
              center: const Offset(0.5, 0.93),
              child: GuideCallout(
                label: '참여 코드 입력 · QR 스캔도 가능',
                fontSize: unit * 0.036,
                icon: Icons.qr_code_2,
                emphasized: true,
              ),
            ),
            placeLabel(
              center: const Offset(0.5, 0.07),
              child: Text(
                '휴대폰은 각자 손에',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: unit * 0.036,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildPhone(
    BuildContext context,
    Size board,
    double unit,
    int index,
  ) {
    final spot = _phoneSpots[index];
    final appear = segment(
      t,
      0.05 + index * 0.06,
      0.3 + index * 0.06,
      curve: Curves.easeOutBack,
    );
    final flightStart = 0.34 + index * 0.09;
    final flight = segment(
      t,
      flightStart,
      flightStart + 0.22,
      curve: Curves.easeInOut,
    );
    final joined = segment(t, flightStart + 0.2, flightStart + 0.32);

    // 바깥에서 안쪽으로 살짝 들어오며 나타납니다.
    final entryShift = (spot.dx < 0.5 ? -1 : 1) * 0.05 * (1 - appear);
    final phoneCenter = Offset(spot.dx + entryShift, spot.dy);
    final packetCenter = Offset(
      0.5 + (phoneCenter.dx - 0.5) * flight,
      0.5 + (phoneCenter.dy - 0.5) * flight - 0.07 * math.sin(math.pi * flight),
    );

    return <Widget>[
      placeAt(
        board: board,
        center: phoneCenter,
        child: Opacity(
          opacity: appear.clamp(0.0, 1.0),
          child: GuidePhone(
            width: unit * 0.115,
            glow:
                joined *
                (1 - segment(t, flightStart + 0.34, flightStart + 0.5)),
            tilt: (spot.dx < 0.5 ? -1 : 1) * 0.06,
            child: _PhoneJoinScreen(unit: unit, joined: joined),
          ),
        ),
      ),
      if (flight > 0 && flight < 1)
        placeAt(
          board: board,
          center: packetCenter,
          child: _CodePacket(unit: unit),
        ),
    ];
  }
}

/// 태블릿에 떠 있는 참여 코드와 QR입니다.
class _TabletCodeScreen extends StatelessWidget {
  const _TabletCodeScreen({required this.unit});

  final double unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Padding(
      padding: EdgeInsets.all(unit * 0.02),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(unit * 0.012),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(unit * 0.012),
              ),
              child: SizedBox(
                width: unit * 0.11,
                height: unit * 0.11,
                // qr_flutter 새 판에서 생성자가 const가 아니게 바뀌었습니다.
                child: QrImageView(
                  data: _sampleRoomCode,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(width: unit * 0.025),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '참여 코드',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: unit * 0.026,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: unit * 0.008),
                Text(
                  _sampleRoomCode,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: unit * 0.055,
                    fontWeight: FontWeight.w900,
                    letterSpacing: unit * 0.004,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 참여 코드가 휴대폰으로 날아가는 조각입니다.
class _CodePacket extends StatelessWidget {
  const _CodePacket({required this.unit});

  final double unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: unit * 0.022,
        vertical: unit * 0.012,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(unit * 0.03),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.45),
            blurRadius: unit * 0.05,
          ),
        ],
      ),
      child: Text(
        _sampleRoomCode,
        style: TextStyle(
          color: Colors.white,
          fontSize: unit * 0.028,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 휴대폰 화면: 코드 입력 → 입장 완료.
class _PhoneJoinScreen extends StatelessWidget {
  const _PhoneJoinScreen({required this.unit, required this.joined});

  final double unit;
  final double joined;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 1 - joined,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: unit * 0.07,
                height: unit * 0.024,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(unit * 0.006),
                  border: Border.all(color: colors.border),
                ),
              ),
              SizedBox(height: unit * 0.01),
              Container(
                width: unit * 0.07,
                height: unit * 0.016,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(unit * 0.006),
                ),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: joined,
          child: Transform.scale(
            scale: 0.6 + 0.4 * joined,
            child: Icon(
              Icons.check_circle,
              color: colors.success,
              size: unit * 0.05,
            ),
          ),
        ),
      ],
    );
  }
}

//=======================03 둘러앉기==============================
class _TakeSeatsScene extends StatelessWidget {
  const _TakeSeatsScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = Size(constraints.maxWidth, constraints.maxHeight);
        final unit = board.shortestSide;
        // 실제 게임의 자리 배치와 같은 좌표 계산을 그대로 씁니다.
        final seats = normalizedPlayerCenters(_characterIds.length);
        final avatarSize = unit * 0.17;

        return Stack(
          children: [
            placeAt(
              board: board,
              center: const Offset(0.5, 0.5),
              child: GuideTable(
                size: Size(board.width * 0.42, board.height * 0.42),
              ),
            ),
            for (var index = 0; index < seats.length; index++)
              placeAt(
                board: board,
                center: seats[index],
                child: GuideSeat(
                  diameter: avatarSize,
                  opacity:
                      segment(t, 0.02 + index * 0.04, 0.18 + index * 0.04) *
                      (1 - segment(t, 0.2 + index * 0.11, 0.5 + index * 0.11)),
                ),
              ),
            placeAt(
              board: board,
              center: const Offset(0.5, 0.5),
              child: GuideTablet(
                width: unit * 0.3,
                child: _TabletSeatingScreen(
                  unit: unit,
                  seatedCount: _seatedCount(),
                ),
              ),
            ),
            for (var index = 0; index < seats.length; index++)
              ..._buildAvatar(board, unit, avatarSize, seats, index),
            placeLabel(
              center: const Offset(0.5, 0.95),
              child: Opacity(
                opacity: segment(t, 0.78, 0.9),
                child: GuideCallout(
                  label: '앉은 순서 그대로 자리를 맞춰요',
                  fontSize: unit * 0.036,
                  icon: Icons.event_seat,
                  emphasized: true,
                ),
              ),
            ),
            placeLabel(
              center: const Offset(0.5, 0.05),
              child: Text(
                '태블릿을 가운데 두고 둥글게',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: unit * 0.036,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _seatedCount() {
    var count = 0;
    for (var index = 0; index < _characterIds.length; index++) {
      if (t >= 0.22 + index * 0.11 + 0.28) count++;
    }
    return count;
  }

  List<Widget> _buildAvatar(
    Size board,
    double unit,
    double avatarSize,
    List<Offset> seats,
    int index,
  ) {
    final start = 0.2 + index * 0.11;
    final walk = segment(t, start, start + 0.3, curve: Curves.easeInOutCubic);
    if (walk <= 0) return const <Widget>[];

    // 화면 아래에서 걸어 들어와 자기 자리에 앉습니다.
    const entry = Offset(0.5, 1.16);
    final seat = seats[index];
    final center = Offset(
      entry.dx + (seat.dx - entry.dx) * walk,
      entry.dy + (seat.dy - entry.dy) * walk,
    );
    final settle = segment(t, start + 0.26, start + 0.44);
    final pop = math.sin(math.pi * settle) * 0.12;

    return <Widget>[
      placeAt(
        board: board,
        center: center,
        child: Transform.scale(
          scale: 0.8 + 0.2 * walk + pop,
          child: GuideAvatar(
            characterId: _characterIds[index],
            diameter: avatarSize,
            highlighted: settle > 0 && settle < 1,
          ),
        ),
      ),
    ];
  }
}

/// 태블릿에 뜨는 자리 배치 현황입니다.
class _TabletSeatingScreen extends StatelessWidget {
  const _TabletSeatingScreen({required this.unit, required this.seatedCount});

  final double unit;
  final int seatedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return GuideScreenFit(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '자리 배치',
            style: TextStyle(
              color: colors.text,
              fontSize: unit * 0.032,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: unit * 0.012),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < _characterIds.length; index++)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: unit * 0.004),
                  width: unit * 0.016,
                  height: unit * 0.016,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < seatedCount
                        ? colors.primary
                        : colors.surfaceMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

//=======================04 함께 보는 화면과 나만 보는 화면==============================
class _PlayScene extends StatelessWidget {
  const _PlayScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = Size(constraints.maxWidth, constraints.maxHeight);
        final unit = board.shortestSide;
        // 사람 옆에 휴대폰까지 놓이므로 자리 원을 조금 좁혀 판 안에 담습니다.
        final seats = normalizedPlayerCenters(_characterIds.length)
            .map(
              (seat) => Offset(
                0.5 + (seat.dx - 0.5) * 0.9,
                0.5 + (seat.dy - 0.5) * 0.9,
              ),
            )
            .toList(growable: false);
        final avatarSize = unit * 0.15;

        // 차례가 자리를 따라 한 바퀴 돕니다.
        final turnValue = t * _characterIds.length;
        final activeIndex = turnValue.floor() % _characterIds.length;
        final turnProgress = turnValue - turnValue.floor();
        final pulse = math.sin(math.pi * turnProgress);

        return Stack(
          children: [
            placeAt(
              board: board,
              center: const Offset(0.5, 0.5),
              child: GuideTable(
                size: Size(board.width * 0.4, board.height * 0.4),
              ),
            ),
            placeAt(
              board: board,
              center: const Offset(0.5, 0.5),
              child: GuideTablet(
                width: unit * 0.32,
                glow: 0.25 + 0.15 * pulse,
                child: _TabletBoardScreen(
                  unit: unit,
                  activeIndex: activeIndex,
                  characterId: _characterIds[activeIndex],
                ),
              ),
            ),
            for (var index = 0; index < seats.length; index++)
              ..._buildSeat(
                board: board,
                unit: unit,
                avatarSize: avatarSize,
                seat: seats[index],
                index: index,
                isActive: index == activeIndex,
                pulse: pulse,
              ),
            placeLabel(
              center: const Offset(0.5, 0.03),
              child: Text(
                '태블릿 = 모두가 함께 보는 게임판',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: unit * 0.036,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            placeLabel(
              center: const Offset(0.5, 0.97),
              child: GuideCallout(
                label: '휴대폰 = 나만 보는 카드와 선택',
                fontSize: unit * 0.036,
                icon: Icons.smartphone,
                emphasized: true,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSeat({
    required Size board,
    required double unit,
    required double avatarSize,
    required Offset seat,
    required int index,
    required bool isActive,
    required double pulse,
  }) {
    // 휴대폰은 '손에 든 것'이므로 사람 옆(원의 접선 방향)에 조금 바깥쪽으로
    // 둡니다. 바깥쪽으로만 밀면 맨 위 자리의 휴대폰이 판 밖으로 나갑니다.
    final direction = Offset(
      (seat.dx - 0.5) * board.width,
      (seat.dy - 0.5) * board.height,
    );
    final length = direction.distance == 0 ? 1 : direction.distance;
    final outward = Offset(direction.dx / length, direction.dy / length);
    final beside = Offset(-outward.dy, outward.dx);
    final phoneOffsetPx = beside * (unit * 0.115);
    final phoneCenter = Offset(
      seat.dx + phoneOffsetPx.dx / board.width,
      seat.dy + phoneOffsetPx.dy / board.height,
    );

    return <Widget>[
      placeAt(
        board: board,
        center: phoneCenter,
        child: Transform.scale(
          scale: isActive ? 1 + 0.12 * pulse : 1,
          child: GuidePhone(
            width: unit * 0.075,
            glow: isActive ? pulse : 0,
            tilt: (seat.dx - 0.5) * 0.3,
            child: _PhoneHandScreen(unit: unit, isActive: isActive),
          ),
        ),
      ),
      placeAt(
        board: board,
        center: seat,
        child: GuideAvatar(
          characterId: _characterIds[index],
          diameter: avatarSize,
          highlighted: isActive,
        ),
      ),
    ];
  }
}

/// 태블릿에 뜨는 공용 게임판입니다(지금 누구 차례인지 표시).
class _TabletBoardScreen extends StatelessWidget {
  const _TabletBoardScreen({
    required this.unit,
    required this.activeIndex,
    required this.characterId,
  });

  final double unit;
  final int activeIndex;
  final String characterId;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return GuideScreenFit(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TURN ${activeIndex + 1}',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: unit * 0.026,
              fontWeight: FontWeight.w900,
              letterSpacing: unit * 0.002,
            ),
          ),
          SizedBox(height: unit * 0.01),
          GuideAvatar(characterId: characterId, diameter: unit * 0.075),
          SizedBox(height: unit * 0.012),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < _characterIds.length; index++)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: unit * 0.004),
                  width: index == activeIndex ? unit * 0.026 : unit * 0.014,
                  height: unit * 0.014,
                  decoration: BoxDecoration(
                    color: index == activeIndex
                        ? colors.primary
                        : colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(unit),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 휴대폰 화면: 나만 보는 카드, 내 차례면 선택 버튼이 켜집니다.
class _PhoneHandScreen extends StatelessWidget {
  const _PhoneHandScreen({required this.unit, required this.isActive});

  final double unit;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Padding(
      padding: EdgeInsets.all(unit * 0.008),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: unit * 0.036,
            height: unit * 0.05,
            decoration: BoxDecoration(
              color: isActive ? colors.primarySoft : colors.surfaceMuted,
              borderRadius: BorderRadius.circular(unit * 0.006),
              border: Border.all(
                color: isActive ? colors.primary : colors.border,
              ),
            ),
          ),
          SizedBox(height: unit * 0.008),
          Container(
            width: unit * 0.045,
            height: unit * 0.012,
            decoration: BoxDecoration(
              color: isActive ? colors.primary : colors.surfaceMuted,
              borderRadius: BorderRadius.circular(unit * 0.006),
            ),
          ),
        ],
      ),
    );
  }
}
