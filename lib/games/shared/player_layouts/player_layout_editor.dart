import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/games/shared/widgets/game_setup_back_button.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/theme/platform_theme.dart';

typedef PlayerLayoutPrepared =
    Future<bool> Function(PlayerLayoutModel playerLayout);
typedef PlayerLayoutCompleted = void Function(PlayerLayoutModel playerLayout);
typedef PlayerLayoutCancelled = Future<bool> Function();

/// 자리 배치 완료 연출에서 의자가 좌석 순서대로 진입하도록 만든 진행률입니다.
///
/// 각 의자는 전체 타임라인의 24% 동안 이동하고, 남은 의자 구간을 좌석 수에
/// 맞춰 시작 시간차로 나눕니다. 마지막 의자는 타임라인 1.0에 도착합니다.
double chairEntranceProgress({
  required double timeline,
  required int seatIndex,
  required int seatCount,
}) {
  if (seatCount <= 0 || seatIndex < 0 || seatIndex >= seatCount) return 0;
  const sequenceStart = 0.52;
  const moveDuration = 0.24;
  final stagger = seatCount == 1
      ? 0.0
      : (1 - sequenceStart - moveDuration) / (seatCount - 1);
  final start = sequenceStart + stagger * seatIndex;
  return Interval(
    start,
    start + moveDuration,
    curve: Curves.easeOutCubic,
  ).transform(timeline.clamp(0.0, 1.0));
}

/// 2~6명의 플레이어 자리를 하나의 화면에서 배치하는 편집기입니다.
class PlayerLayoutEditor extends StatefulWidget {
  PlayerLayoutEditor({
    super.key,
    required this.initialLayout,
    required this.onPrepare,
    required this.onComplete,
    required this.onCancel,
    required this.tableColor,
    this.tableBackgroundImage,
    this.tableImage,
    this.chairImage,
  }) : assert(
         initialLayout.playerCount >= 2 && initialLayout.playerCount <= 12,
         '지원하는 플레이어 수는 2~12명입니다.',
       );

  final PlayerLayoutModel initialLayout;
  final PlayerLayoutPrepared onPrepare;
  final PlayerLayoutCompleted onComplete;
  final PlayerLayoutCancelled onCancel;

  /// 설정 완료 연출에서 중앙 테이블에 쓰는 바탕색입니다. [tableBackgroundImage]가
  /// 없거나 아직 안 그려졌을 때를 대비한 입장할 게임의 배경 이미지와 같은 톤입니다.
  final Color tableColor;

  /// 테이블에 입힐 게임 배경 이미지입니다. 다음 게임 화면과 같은 이미지를 넘기면
  /// 테이블이 확대될 때 이질감 없이 게임 화면으로 이어집니다.
  final ImageProvider? tableBackgroundImage;

  /// 위에서 내려다본 테이블 이미지입니다. 주어지면 [tableColor]로 그리던 원형
  /// 테이블 대신 이 이미지를 씁니다.
  final ImageProvider? tableImage;

  /// 위에서 내려다본 의자 이미지입니다. 등받이가 위, 앉는 방향이 아래를 향하는
  /// 그림을 기준으로 각 자리에서 테이블 중심을 바라보도록 회전시킵니다.
  final ImageProvider? chairImage;

  @override
  State<PlayerLayoutEditor> createState() => _PlayerLayoutEditorState();
}

class _PlayerLayoutEditorState extends State<PlayerLayoutEditor>
    with TickerProviderStateMixin {
  /// 디자인 기준 화면 폭입니다(Figma tablet-screen-8-seating-*: 1280x800).
  static const double _designBoardWidth = 1280;

  /// 안내 문구 알약의 높이입니다(디자인 696x48).
  static const double _bannerHeight = 48;

  /// 가운데 태블릿 자리 표시의 크기입니다(디자인 300x200).
  static const Size _tabletMarkerSize = Size(300, 200);

  /// 인원에 따라 카드가 세 단계로 작아집니다(디자인 4·6인 / 9인 / 12인).
  _SeatCardMetrics _metricsFor(Size boardSize) {
    final base = switch (_playerCount) {
      <= 6 => _SeatCardMetrics.large,
      <= 9 => _SeatCardMetrics.medium,
      _ => _SeatCardMetrics.small,
    };
    // 1280보다 좁은 태블릿에서도 화면 대비 같은 비율로 보이게 줄입니다.
    return base.scaled((boardSize.width / _designBoardWidth).clamp(0.72, 1.15));
  }

  /// 카드 중심이 이만큼 가까워지면 자리를 맞바꿉니다. 카드가 작아질수록
  /// 자리 간격도 좁아지므로 카드 너비에 비례합니다.
  double _swapTriggerDistance(Size cardSize) => cardSize.width * 0.6;

  /// 테이블 크기에 비례해 어느 화면에서도 같은 비율로 보이게 합니다.
  double _chairSizeFor(Size boardSize) =>
      (_tableDiameter(boardSize) * 0.34).clamp(72.0, 170.0);
  static const Duration _zoomHold = Duration(seconds: 1);

  // 입장 연출(블록 퇴장 → 테이블 등장 → 의자 착석)은 [_entranceController]로,
  // 그 뒤 테이블로 카메라가 줌인해 화면이 게임 배경색으로 가득 차는 연출은
  // 별도의 [_zoomController]로 재생합니다. 둘을 분리해야 착석이 끝난 뒤 잠깐
  // 멈춰 있다가(=_zoomHold) 줌인을 시작할 수 있습니다.
  static const Interval _exitInterval = Interval(
    0,
    0.42,
    curve: Curves.easeInCubic,
  );
  static const Interval _tableInterval = Interval(
    0.30,
    0.62,
    curve: Curves.easeOutBack,
  );
  late List<int> _playerSlotIndexes;
  List<Offset> _slotPositions = const [];
  final Map<int, Offset> _draggingPositions = {};
  late final AnimationController _entranceController;
  late final AnimationController _zoomController;

  int? _draggingPlayerIndex;
  int? _hoveredSlotIndex;
  bool _isCompleting = false;
  bool _isCancelling = false;
  bool _handedOffToGame = false;

  int get _playerCount => widget.initialLayout.playerCount;

  @override
  void initState() {
    super.initState();
    _playerSlotIndexes = List<int>.from(widget.initialLayout.seatIndexes);
    _entranceController = AnimationController(
      vsync: this,
      // 테이블 뒤에 의자가 좌석 순서대로 충분한 시간차를 두고 들어옵니다.
      duration: const Duration(milliseconds: 2300),
    );
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant PlayerLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 자리에서 참가자 수가 바뀌면 좌석표를 다시 만듭니다. 이전 좌석표를
    // 그대로 쓰면 자리 번호가 범위를 벗어나 화면이 깨집니다.
    if (oldWidget.initialLayout.playerCount !=
        widget.initialLayout.playerCount) {
      _playerSlotIndexes = List<int>.from(widget.initialLayout.seatIndexes);
      _draggingPositions.clear();
      _draggingPlayerIndex = null;
      _hoveredSlotIndex = null;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _zoomController.dispose();
    if (!_handedOffToGame) {
      //================상태바 표시=================
      // 자리 배치를 취소한 경우에는 게임으로 넘기지 않았으므로 플랫폼 상태바를 복원합니다.
      unawaited(AppSystemUi.showPlatformSystemBars());
    }
    super.dispose();
  }

  void _startDragging(int playerIndex) {
    final currentSlotIndex = _playerSlotIndexes[playerIndex];

    setState(() {
      _draggingPlayerIndex = playerIndex;
      _hoveredSlotIndex = null;
      _draggingPositions[playerIndex] = _slotPositions[currentSlotIndex];
    });
  }

  Future<void> _cancel() async {
    if (_isCompleting || _isCancelling || !mounted) return;
    setState(() => _isCancelling = true);
    final canLeave = await widget.onCancel();
    if (!mounted) return;
    if (canLeave) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isCancelling = false);
  }

  void _movePlayer({
    required int playerIndex,
    required DragUpdateDetails details,
    required Size boardSize,
    required Size cardSize,
  }) {
    final currentPosition =
        _draggingPositions[playerIndex] ??
        _slotPositions[_playerSlotIndexes[playerIndex]];

    final maxX = math.max(0.0, 1 - (cardSize.width / boardSize.width));
    final maxY = math.max(0.0, 1 - (cardSize.height / boardSize.height));
    final nextPosition = Offset(
      (currentPosition.dx + details.delta.dx / boardSize.width).clamp(0, maxX),
      (currentPosition.dy + details.delta.dy / boardSize.height).clamp(0, maxY),
    );

    setState(() {
      _draggingPositions[playerIndex] = nextPosition;
    });

    _checkNearbySlot(
      playerIndex: playerIndex,
      draggingPosition: nextPosition,
      boardSize: boardSize,
      cardSize: cardSize,
    );
  }

  void _checkNearbySlot({
    required int playerIndex,
    required Offset draggingPosition,
    required Size boardSize,
    required Size cardSize,
  }) {
    final draggedCenter = Offset(
      draggingPosition.dx * boardSize.width + cardSize.width / 2,
      draggingPosition.dy * boardSize.height + cardSize.height / 2,
    );
    final currentSlotIndex = _playerSlotIndexes[playerIndex];
    final trigger = _swapTriggerDistance(cardSize);

    int? nearbySlotIndex;
    double nearestDistance = double.infinity;

    for (var slotIndex = 0; slotIndex < _slotPositions.length; slotIndex++) {
      if (slotIndex == currentSlotIndex) continue;

      final slotPosition = _slotPositions[slotIndex];
      final slotCenter = Offset(
        slotPosition.dx * boardSize.width + cardSize.width / 2,
        slotPosition.dy * boardSize.height + cardSize.height / 2,
      );
      final distance = (draggedCenter - slotCenter).distance;

      if (distance <= trigger && distance < nearestDistance) {
        nearestDistance = distance;
        nearbySlotIndex = slotIndex;
      }
    }

    if (nearbySlotIndex == null) {
      _hoveredSlotIndex = null;
      return;
    }
    if (_hoveredSlotIndex == nearbySlotIndex) return;

    _swapPlayerSlots(
      playerIndex: playerIndex,
      targetSlotIndex: nearbySlotIndex,
    );
    _hoveredSlotIndex = nearbySlotIndex;
  }

  void _swapPlayerSlots({
    required int playerIndex,
    required int targetSlotIndex,
  }) {
    final currentSlotIndex = _playerSlotIndexes[playerIndex];
    if (currentSlotIndex == targetSlotIndex) return;

    final targetPlayerIndex = _playerSlotIndexes.indexOf(targetSlotIndex);
    setState(() {
      if (targetPlayerIndex != -1 && targetPlayerIndex != playerIndex) {
        _playerSlotIndexes[targetPlayerIndex] = currentSlotIndex;
      }
      _playerSlotIndexes[playerIndex] = targetSlotIndex;
    });
  }

  void _finishDragging(int playerIndex) {
    setState(() {
      _draggingPositions.remove(playerIndex);
      _draggingPlayerIndex = null;
      _hoveredSlotIndex = null;
    });
  }

  Future<void> _completeSetting() async {
    if (_isCompleting) return;
    var handedOffToGame = false;

    final completedLayout = widget.initialLayout.updateSeats(
      _playerSlotIndexes,
    );

    debugPrint('플레이어 자리 번호: ${completedLayout.seatIndexes}');
    setState(() {
      _isCompleting = true;
    });

    try {
      // 게임 화면의 첫 프레임에서 배경 디코딩을 기다리며 검게 보이지 않도록,
      // 자리 배치 연출과 동시에 다음 화면 배경을 메모리에 준비합니다.
      final backgroundReady = _precacheGameBackground();

      // 1) 블록 퇴장 → 테이블 → 의자 착석을 끝까지 재생합니다.
      await _entranceController.forward(from: 0);
      if (!mounted) return;
      // 2) 착석한 모습을 잠깐 보여준 뒤에야 줌인을 시작합니다.
      await Future<void>.delayed(_zoomHold);
      if (!mounted) return;

      // 3) 좌석 저장과 서버 게임 생성을 줌 전에 끝냅니다. 서버 응답을 테이블이
      // 화면 전체를 덮은 뒤 기다리면 마지막 어두운 프레임이 고정되어 검은 화면처럼
      // 보입니다. 준비가 길어져도 Scrim이나 로딩 없이 테이블 화면을 유지합니다.
      final prepared = await widget.onPrepare(completedLayout);
      if (!mounted) return;
      if (!prepared) return;
      await backgroundReady;
      if (!mounted) return;

      // 4) 서버 상태와 배경이 준비된 뒤에만 줌인하고, 완료 즉시 게임 화면으로
      // 교체합니다. 줌 완료 프레임에서는 네트워크 작업을 절대 기다리지 않습니다.
      await _zoomController.forward(from: 0);
      if (!mounted) return;
      handedOffToGame = true;
      _handedOffToGame = true;
      widget.onComplete(completedLayout);
    } finally {
      // 준비가 실패한 경우만 다시 배치할 수 있도록 연출을 되돌립니다.
      // pushReplacement를 호출한 직후에는 기존 route가 아직 mounted일 수 있으므로,
      // mounted만 보고 reverse하면 성공한 줌인을 다시 되감아 검은 전환을 만들게 됩니다.
      if (!handedOffToGame && mounted) {
        await _zoomController.reverse();
        if (mounted) await _entranceController.reverse();
        if (mounted) {
          setState(() {
            _isCompleting = false;
          });
        }
      }
    }
  }

  Future<void> _precacheGameBackground() async {
    final background = widget.tableBackgroundImage;
    if (background == null) return;
    try {
      await precacheImage(background, context);
    } catch (error) {
      // 게임 화면 자체에도 배경의 대체 색상이 있으므로 이미지 캐시 실패만으로
      // 서버 게임 시작이나 화면 전환을 막지 않습니다.
      debugPrint('게임 배경 이미지를 미리 준비하지 못했습니다: $error');
    }
  }

  Offset _slotCenterPixel(int slotIndex, Size boardSize, Size cardSize) {
    final normalized = _slotPositions[slotIndex];
    return Offset(
      normalized.dx * boardSize.width + cardSize.width / 2,
      normalized.dy * boardSize.height + cardSize.height / 2,
    );
  }

  /// 화면 중심에서 바깥쪽으로 밀어낸, 화면 밖의 한 지점입니다. 블록은 이 지점을
  /// 향해 퇴장하고, 의자는 이 지점에서부터 자리로 들어옵니다.
  Offset _offscreenCenterPixel(int slotIndex, Size boardSize, Size cardSize) {
    final startCenter = _slotCenterPixel(slotIndex, boardSize, cardSize);
    final boardCenter = Offset(boardSize.width / 2, boardSize.height / 2);
    var direction = startCenter - boardCenter;
    if (direction.distance < 1) direction = const Offset(0, -1);
    final unit = direction / direction.distance;
    return startCenter + unit * boardSize.longestSide;
  }

  double _tableDiameter(Size boardSize) => boardSize.shortestSide * 0.46;

  /// 테이블 원이 화면 대각선을 완전히 덮을 때까지 확대하는 데 필요한 배율입니다.
  /// boardSize는 안내 문구·세이프 영역을 뺀 콘텐츠 영역이라, 화면 전체를
  /// 확실히 덮도록 여유를 넉넉히 둡니다.
  double _maxZoomScale(Size boardSize) {
    final diameter = _tableDiameter(boardSize);
    if (diameter <= 0) return 1;
    final diagonal = math.sqrt(
      boardSize.width * boardSize.width + boardSize.height * boardSize.height,
    );
    return (diagonal * 1.35) / diameter;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              if (!_isCompleting)
                Padding(
                  padding: GameSetupBackButton.rowPadding,
                  child: SizedBox(
                    height: GameSetupBackButton.rowHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 디자인: 696x48 알약 안에 19px 안내 문구. 뒤로가기
                        // 버튼과 겹치지 않게 좌우를 비워 둡니다.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 64),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 696),
                            child: Container(
                              height: _bannerHeight,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '드래그를 사용하여 플레이어들의 실제 위치와 맞도록 조정해 주세요.',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          // 역할 배치 화면과 같은 버튼입니다.
                          child: GameSetupBackButton(
                            isBusy: _isCancelling,
                            onPressed: () => unawaited(_cancel()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final metrics = _metricsFor(boardSize);
                    _slotPositions = seatingCardTopLeftPositions(
                      playerCount: _playerCount,
                      boardSize: boardSize,
                      cardSize: metrics.size,
                    );

                    return AnimatedBuilder(
                      animation: Listenable.merge([
                        _entranceController,
                        _zoomController,
                      ]),
                      builder: (context, _) {
                        final t = _entranceController.value;
                        final zoomT = Curves.easeInCubic.transform(
                          _zoomController.value,
                        );
                        final zoomScale =
                            1 + (_maxZoomScale(boardSize) - 1) * zoomT;
                        return Transform.scale(
                          scale: zoomScale,
                          child: Stack(
                            children: [
                              if (!_isCompleting)
                                _buildTabletMarker(
                                  boardSize: boardSize,
                                  metrics: metrics,
                                  colors: colors,
                                ),
                              for (
                                var playerIndex = 0;
                                playerIndex < _playerCount;
                                playerIndex++
                              )
                                _buildPlayer(
                                  playerIndex: playerIndex,
                                  boardSize: boardSize,
                                  metrics: metrics,
                                  t: t,
                                ),
                              _buildTable(boardSize: boardSize, t: t),
                              for (
                                var seatIndex = 0;
                                seatIndex < _playerCount;
                                seatIndex++
                              )
                                _buildChair(
                                  seatIndex: seatIndex,
                                  boardSize: boardSize,
                                  cardSize: metrics.size,
                                  t: t,
                                ),
                              if (!_isCompleting)
                                Positioned(
                                  // 디자인: 208x64, radius 12, 오른쪽·아래 28
                                  right: 28,
                                  bottom: 28,
                                  child: SizedBox(
                                    width: 208,
                                    height: 64,
                                    child: FilledButton(
                                      onPressed: _completeSetting,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        '설정 완료',
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer({
    required int playerIndex,
    required Size boardSize,
    required _SeatCardMetrics metrics,
    required double t,
  }) {
    final player = widget.initialLayout.players[playerIndex];
    final slotIndex = _playerSlotIndexes[playerIndex];
    final isDragging = _draggingPlayerIndex == playerIndex;

    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _isCompleting ? null : (_) => _startDragging(playerIndex),
      onPanUpdate: _isCompleting
          ? null
          : (details) => _movePlayer(
              playerIndex: playerIndex,
              details: details,
              boardSize: boardSize,
              cardSize: metrics.size,
            ),
      onPanEnd: _isCompleting ? null : (_) => _finishDragging(playerIndex),
      onPanCancel: _isCompleting ? null : () => _finishDragging(playerIndex),
      child: _SeatCard(
        player: player,
        metrics: metrics,
        isDragging: isDragging,
      ),
    );

    if (_isCompleting) {
      final exitT = _exitInterval.transform(t);
      final center = Offset.lerp(
        _slotCenterPixel(slotIndex, boardSize, metrics.size),
        _offscreenCenterPixel(slotIndex, boardSize, metrics.size),
        exitT,
      )!;
      return Positioned(
        key: ValueKey(player.uid),
        left: center.dx - metrics.size.width / 2,
        top: center.dy - metrics.size.height / 2,
        child: child,
      );
    }

    final position = isDragging
        ? _draggingPositions[playerIndex] ?? _slotPositions[slotIndex]
        : _slotPositions[slotIndex];

    return AnimatedPositioned(
      key: ValueKey(player.uid),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: position.dx * boardSize.width,
      top: position.dy * boardSize.height,
      child: child,
    );
  }

  // Stack의 다른 자식은 전부 Positioned/AnimatedPositioned라 "위치 없는" 자식이
  // 하나도 없어야 합니다. 가로 제약이 loose이기 때문에, 여기서 Positioned가
  // 아닌 위젯(SizedBox.shrink() 등)을 반환하면 Stack 전체 너비가 0으로
  // 줄어들어 자리 배치 블록·버튼이 통째로 사라집니다. 그래서 안 보일 때도
  // Transform.scale(scale: 0)으로 숨기지, 위젯 자체를 빼지 않습니다.
  Widget _buildTable({required Size boardSize, required double t}) {
    final tableT = _tableInterval.transform(t);
    final diameter = _tableDiameter(boardSize);
    return Positioned(
      left: boardSize.width / 2 - diameter / 2,
      top: boardSize.height / 2 - diameter / 2,
      width: diameter,
      height: diameter,
      child: Transform.scale(
        scale: tableT.clamp(0.0, 1.5),
        child: widget.tableImage != null
            // 테이블 이미지는 이미 원형과 그림자를 포함하므로 그대로 그립니다.
            ? Image(image: widget.tableImage!, fit: BoxFit.contain)
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.tableColor,
                  image: widget.tableBackgroundImage == null
                      ? null
                      : DecorationImage(
                          image: widget.tableBackgroundImage!,
                          fit: BoxFit.cover,
                        ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  //=======================태블릿 자리 표시==============================
  /// 디자인의 가운데 안내 상자입니다(300x200, 점선 테두리).
  ///
  /// 실제 태블릿이 놓이는 자리를 알려 주어, 참가자들이 자기 자리를 태블릿을
  /// 기준으로 맞출 수 있게 합니다. 설정 완료 연출이 시작되면 테이블이 이
  /// 자리를 대신하므로 표시를 지웁니다.
  Widget _buildTabletMarker({
    required Size boardSize,
    required _SeatCardMetrics metrics,
    required PlatformColors colors,
  }) {
    // 카드와 같은 배율로 줄여, 좁은 태블릿에서도 자리 사이 여백이 유지됩니다.
    final scale = metrics.size.width / _SeatCardMetrics.large.size.width;
    final size = Size(
      _tabletMarkerSize.width * scale,
      _tabletMarkerSize.height * scale,
    );
    return Positioned(
      left: boardSize.width / 2 - size.width / 2,
      top: boardSize.height / 2 - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(20 * scale),
          ),
          child: _DashedRoundedRect(
            color: colors.border,
            radius: 20 * scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '태블릿',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 21 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Text(
                  '테이블 중앙',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 16 * scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChair({
    required int seatIndex,
    required Size boardSize,
    required Size cardSize,
    required double t,
  }) {
    final chairT = chairEntranceProgress(
      timeline: t,
      seatIndex: seatIndex,
      seatCount: _playerCount,
    );
    final seatCenter = _slotCenterPixel(seatIndex, boardSize, cardSize);
    final center = Offset.lerp(
      _offscreenCenterPixel(seatIndex, boardSize, cardSize),
      seatCenter,
      chairT,
    )!;
    final chairSize = _chairSizeFor(boardSize);

    final chairImage = widget.chairImage;
    if (chairImage == null) {
      return Positioned(
        left: center.dx - chairSize / 2,
        top: center.dy - chairSize / 2,
        width: chairSize,
        height: chairSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.tableColor, width: 3),
          ),
          child: Icon(Icons.event_seat, color: widget.tableColor, size: 40),
        ),
      );
    }

    //=======================의자 방향==============================
    // 의자 이미지는 등받이가 위, 앉는 방향이 아래(+Y, 각도 pi/2)입니다. 자리에서
    // 테이블 중심을 바라보는 각도로 돌려, 어느 자리든 책상을 향해 앉습니다.
    final boardCenter = Offset(boardSize.width / 2, boardSize.height / 2);
    var towardTable = boardCenter - seatCenter;
    if (towardTable.distance < 1) towardTable = const Offset(0, 1);
    final rotation = math.atan2(towardTable.dy, towardTable.dx) - math.pi / 2;

    return Positioned(
      left: center.dx - chairSize / 2,
      top: center.dy - chairSize / 2,
      width: chairSize,
      height: chairSize,
      child: Transform.rotate(
        angle: rotation,
        child: Image(image: chairImage, fit: BoxFit.contain),
      ),
    );
  }
}

class _SeatCardMetrics {
  const _SeatCardMetrics({
    required this.size,
    required this.avatar,
    required this.radius,
    required this.nicknameSize,
    required this.padding,
    required this.gap,
  });

  /// 4·6인 (Figma tablet-screen-8-seating-4 / -6)
  static const large = _SeatCardMetrics(
    size: Size(220, 92),
    avatar: 56,
    radius: 16,
    nicknameSize: 32,
    padding: 16,
    gap: 12,
  );

  /// 7~9인 (Figma tablet-screen-8-seating-9)
  static const medium = _SeatCardMetrics(
    size: Size(176, 76),
    avatar: 44,
    radius: 14,
    nicknameSize: 24,
    padding: 16,
    gap: 12,
  );

  /// 10~12인 (Figma tablet-screen-8-seating-12)
  static const small = _SeatCardMetrics(
    size: Size(128, 64),
    avatar: 36,
    radius: 12,
    nicknameSize: 18,
    padding: 14,
    gap: 12,
  );

  final Size size;
  final double avatar;
  final double radius;
  final double nicknameSize;
  final double padding;
  final double gap;

  double get avatarRadius => avatar * 0.25;

  _SeatCardMetrics scaled(double scale) => _SeatCardMetrics(
    size: Size(size.width * scale, size.height * scale),
    avatar: avatar * scale,
    radius: radius * scale,
    nicknameSize: nicknameSize * scale,
    padding: padding * scale,
    gap: gap * scale,
  );
}

//=======================플레이어 카드==============================
/// 자리 하나를 나타내는 카드입니다.
///
/// 디자인(Figma tablet-screen-8-seating-*): 흰 배경 + 옅은 테두리, 왼쪽에
/// 캐릭터, 오른쪽에 닉네임. 드래그 중에는 1.06배로 커지고 테두리가 보라색으로,
/// 배경이 연보라로 바뀌어 "지금 옮기는 카드"가 한눈에 보입니다.
class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.player,
    required this.metrics,
    required this.isDragging,
  });

  final PlayerLayoutPlayer player;
  final _SeatCardMetrics metrics;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: AnimatedScale(
        scale: isDragging ? 1.06 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: metrics.size.width,
          height: metrics.size.height,
          padding: EdgeInsets.symmetric(horizontal: metrics.padding),
          decoration: BoxDecoration(
            color: isDragging ? colors.primarySoft : colors.surface,
            borderRadius: BorderRadius.circular(metrics.radius),
            border: Border.all(
              color: isDragging ? colors.primary : colors.border,
              width: isDragging ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: metrics.avatar,
                height: metrics.avatar,
                padding: EdgeInsets.all(metrics.avatar * 0.08),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(metrics.avatarRadius),
                ),
                child: Image.asset(
                  roomCharacterAssetPath(player.characterId),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: metrics.gap),
              Expanded(
                child: Text(
                  player.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: metrics.nicknameSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//=======================점선 테두리==============================
/// 태블릿 자리 표시의 점선 사각형입니다(디자인: 2px, 8/6 점선).
class _DashedRoundedRect extends StatelessWidget {
  const _DashedRoundedRect({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    const dash = 8.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
