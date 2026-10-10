// [player_layout_editor.dart] 는 태블릿에서 플레이어 자리 배치를 편집하는 화면을 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [PlayerLayout] : 태블릿의 플레이어 자리 배치와 편집 규칙을 관리함
//
// 즉, 인원과 기기 크기에 맞춰 자리를 안정적으로 배치하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/tablet/widgets/game_setup_back_button.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';

// ============================================================

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
    this.seatTheme = MosiSeatTheme.fallback,
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

  /// 시안(SeatSync)의 게임별 색입니다. 플랫폼이 게임 id로 골라 넘깁니다.
  final MosiSeatTheme seatTheme;

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
  static const Duration _zoomHold = Duration(milliseconds: 250);

  // 입장 연출(블록 퇴장 → 테이블 등장 → 의자 착석)은 [_entranceController]로,
  // 그 뒤 테이블로 카메라가 줌인해 화면이 게임 배경색으로 가득 차는 연출은
  // 별도의 [_zoomController]로 재생합니다. 둘을 분리해야 착석이 끝난 뒤 잠깐
  // 멈춰 있다가(=_zoomHold) 줌인을 시작할 수 있습니다.
  /// 입장 연출 2.3초 안의 시각(초)입니다. 시안 SeatSync의 타임라인을 따릅니다.
  static const double _entranceSeconds = 1.6;

  /// [start]초부터 [duration]초 동안의 진행률(0~1)입니다.
  double _phase(
    double t,
    double start,
    double duration, [
    Curve curve = Curves.linear,
  ]) {
    final seconds = t * _entranceSeconds;
    return curve.transform(((seconds - start) / duration).clamp(0.0, 1.0));
  }

  /// 좌석 순서에 따른 시간차(초)입니다. 첫 의자는 0.4초, 마지막 의자는 0.95초에
  /// 나타나기 시작해 1.5초 안에 모두 자리를 잡습니다.
  double _seatDelay(int seatIndex) {
    if (_playerCount <= 1) return 0.4;
    return 0.4 + 0.55 * seatIndex / (_playerCount - 1);
  }

  late List<int> _playerSlotIndexes;

  /// 자리를 바꿀 때마다 올라가는 카드별 도착 번호입니다. 번호가 바뀐 카드는
  /// 새 자리에 닿는 순간 테두리가 한 번 반짝입니다(로비 연출 7번).
  final Map<int, int> _arrivals = {};
  List<Offset> _slotPositions = const [];
  final Map<int, Offset> _draggingPositions = {};
  late final AnimationController _entranceController;
  late final AnimationController _zoomController;
  late final Listenable _transitionAnimation;

  int? _draggingPlayerIndex;
  int? _hoveredSlotIndex;

  /// 눌러서 고른 자리입니다. 다른 자리를 누르면 두 자리를 맞바꿉니다.
  int? _selectedSlotIndex;
  final math.Random _random = math.Random();
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
      duration: const Duration(milliseconds: 1600),
    );
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _transitionAnimation = Listenable.merge([
      _entranceController,
      _zoomController,
    ]);
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
      _selectedSlotIndex = null;
      _draggingPlayerIndex = playerIndex;
      _hoveredSlotIndex = null;
      _draggingPositions[playerIndex] = _slotPositions[currentSlotIndex];
    });
  }

  /// 카드를 눌러 고르고, 다른 카드를 눌러 맞바꿉니다(시안). 끌어서 옮기기도
  /// 그대로 쓸 수 있습니다.
  void _tapPlayer(int playerIndex) {
    if (_isCompleting) return;
    final slot = _playerSlotIndexes[playerIndex];
    final selected = _selectedSlotIndex;
    if (selected == null) {
      setState(() => _selectedSlotIndex = slot);
      return;
    }
    if (selected == slot) {
      setState(() => _selectedSlotIndex = null);
      return;
    }
    final selectedPlayer = _playerSlotIndexes.indexOf(selected);
    setState(() {
      if (selectedPlayer != -1) _playerSlotIndexes[selectedPlayer] = slot;
      _playerSlotIndexes[playerIndex] = selected;
      _selectedSlotIndex = null;
    });
  }

  void _shuffle() {
    if (_isCompleting) return;
    final slots = List<int>.generate(_playerCount, (index) => index)
      ..shuffle(_random);
    setState(() {
      _playerSlotIndexes = slots;
      _selectedSlotIndex = null;
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
        _arrivals.update(targetPlayerIndex, (n) => n + 1, ifAbsent: () => 1);
      }
      _playerSlotIndexes[playerIndex] = targetSlotIndex;
      _arrivals.update(playerIndex, (n) => n + 1, ifAbsent: () => 1);
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
      _selectedSlotIndex = null;
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
    final theme = widget.seatTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: theme.ground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            final safe = MediaQuery.paddingOf(context);
            final boardTop =
                safe.top +
                GameSetupBackButton.rowPadding.vertical +
                GameSetupBackButton.rowHeight +
                12;
            final boardRect = Rect.fromLTWH(
              safe.left,
              boardTop,
              viewport.width - safe.horizontal,
              math.max(0, viewport.height - boardTop - safe.bottom),
            );
            return AnimatedBuilder(
              animation: _transitionAnimation,
              builder: (context, _) {
                final t = _entranceController.value;
                final uiOpacity = _isCompleting
                    ? 1 - _phase(t, 0, 0.3, Curves.easeIn)
                    : 1.0;
                // 배경은 상단 안내줄·안전 여백까지 화면 전체에 그립니다.
                // 버튼과 좌석은 기존 안전 영역과 위치를 유지합니다.
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: boardRect,
                      child: Transform.scale(
                        scale: _zoomScaleFor(boardRect.size),
                        child: CustomPaint(
                          painter: _DotGridPainter(theme.dots),
                        ),
                      ),
                    ),
                    _buildWorldBackground(viewport, boardRect, t),
                    SafeArea(
                      child: Column(
                        children: [
                          Opacity(
                            opacity: uiOpacity,
                            child: IgnorePointer(
                              ignoring: _isCompleting,
                              child: _buildTopBar(theme),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildBoard(boardRect.size, t, uiOpacity),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(MosiSeatTheme theme) {
    final hint = _selectedSlotIndex != null
        ? '바꿀 상대 자리를 눌러 주세요.'
        : '실제로 앉은 자리에 맞게 이름 카드를 옮겨 주세요.';
    return Padding(
      padding: GameSetupBackButton.rowPadding,
      child: SizedBox(
        height: GameSetupBackButton.rowHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 시안: 최대 696 알약 안에 19px 안내 문구. 좌우 버튼과 겹치지 않게
            // 비워 둡니다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 120),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 696),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: _bannerHeight,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: theme.pill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.pillLine, width: 2),
                  ),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      color: MosiColors.white,
                      size: 19,
                      weight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: MosiButton(
                label: '대기실',
                variant: MosiButtonVariant.outline,
                foreground: MosiColors.white,
                height: 44,
                fontSize: 15,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.chevron_left_rounded),
                loading: _isCancelling,
                onPressed: () => unawaited(_cancel()),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: MosiButton(
                label: '섞기',
                variant: MosiButtonVariant.outline,
                foreground: MosiColors.white,
                height: 44,
                fontSize: 15,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.shuffle_rounded),
                onPressed: _shuffle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _zoomScaleFor(Size boardSize) {
    final zoomT = Curves.easeInOutCubic.transform(_zoomController.value);
    return 1 + (_maxZoomScale(boardSize) - 1) * zoomT;
  }

  Widget _buildWorldBackground(Size viewport, Rect boardRect, double t) {
    // 원의 시작점과 줌 축을 실제 테이블 중심에 맞춥니다. 배경 이미지의
    // cover 기준만 콘텐츠 판에서 화면 전체로 넓혀 위아래 띠를 없앱니다.
    final center = boardRect.center;
    final farthestX = math.max(center.dx, viewport.width - center.dx);
    final farthestY = math.max(center.dy, viewport.height - center.dy);
    final radius = math.sqrt(farthestX * farthestX + farthestY * farthestY) + 1;
    final worldT = _phase(t, 0.2, 0.6, const Cubic(0.6, 0, 0.3, 1));
    return Transform.scale(
      scale: _zoomScaleFor(boardRect.size),
      alignment: Alignment(
        2 * center.dx / viewport.width - 1,
        2 * center.dy / viewport.height - 1,
      ),
      child: ClipPath(
        clipper: _CircleRevealClipper(center: center, radius: radius * worldT),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.tableColor,
            image: widget.tableBackgroundImage == null
                ? null
                : DecorationImage(
                    image: widget.tableBackgroundImage!,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(Size boardSize, double t, double uiOpacity) {
    final theme = widget.seatTheme;
    final metrics = _metricsFor(boardSize);
    _slotPositions = seatingCardTopLeftPositions(
      playerCount: _playerCount,
      boardSize: boardSize,
      cardSize: metrics.size,
    );
    final chairSize = _chairSizeFor(boardSize);
    // 배경과 같은 테이블 중심·배율로 확대해 하나의 화면으로 이어집니다.
    return Transform.scale(
      scale: _zoomScaleFor(boardSize),
      child: Stack(
        children: [
          _buildFlatTable(boardSize: boardSize, t: t),
          _buildTable(boardSize: boardSize, t: t),
          _buildTabletMarker(boardSize: boardSize, metrics: metrics, t: t),
          for (var seatIndex = 0; seatIndex < _playerCount; seatIndex++)
            _buildChair(
              seatIndex: seatIndex,
              boardSize: boardSize,
              cardSize: metrics.size,
              chairSize: chairSize,
              t: t,
            ),
          for (var playerIndex = 0; playerIndex < _playerCount; playerIndex++)
            _buildPlayer(
              playerIndex: playerIndex,
              boardSize: boardSize,
              metrics: metrics,
              t: t,
            ),
          Positioned(
            // 시안: 208x64, radius 12, 오른쪽·아래 28
            right: 28,
            bottom: 28,
            child: IgnorePointer(
              ignoring: _isCompleting,
              child: Opacity(
                opacity: uiOpacity,
                child: SizedBox(
                  width: 208,
                  child: MosiButton(
                    label: '설정 완료',
                    background: theme.button,
                    foreground: theme.buttonFg,
                    shadowColor: theme.deep,
                    shadowOffset: 5,
                    height: 64,
                    fontSize: 21,
                    radius: 12,
                    expand: true,
                    onPressed: _completeSetting,
                  ),
                ),
              ),
            ),
          ),
        ],
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
      onTap: _isCompleting ? null : () => _tapPlayer(playerIndex),
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
        seatNumber: slotIndex + 1,
        metrics: metrics,
        theme: widget.seatTheme,
        isDragging: isDragging,
        isSelected: _selectedSlotIndex == slotIndex,
        arrival: _arrivals[playerIndex] ?? 0,
      ),
    );

    if (_isCompleting) {
      // 시안: 카드는 제자리에서 작아지며 사라지고, 같은 중심에 의자가 나타납니다.
      final cardT = _phase(t, _seatDelay(slotIndex) - 0.1, 0.5, Curves.easeIn);
      final position = _slotPositions[slotIndex];
      return Positioned(
        key: ValueKey(player.uid),
        left: position.dx * boardSize.width,
        top: position.dy * boardSize.height,
        child: IgnorePointer(
          child: Opacity(
            opacity: 1 - cardT,
            child: Transform.scale(scale: 1 - 0.45 * cardT, child: child),
          ),
        ),
      );
    }

    final position = isDragging
        ? _draggingPositions[playerIndex] ?? _slotPositions[slotIndex]
        : _slotPositions[slotIndex];

    return AnimatedPositioned(
      key: ValueKey(player.uid),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 450),
      curve: const Cubic(0.3, 1.3, 0.5, 1),
      left: position.dx * boardSize.width,
      top: position.dy * boardSize.height,
      child: child,
    );
  }

  /// 자리 배치 중 보이는 플랫 테이블입니다. 실제 테이블 그림의 보이는 원과
  /// 같은 크기·위치로 그려, 전환 때 그림만 바뀐 것처럼 보이게 합니다.
  Widget _buildFlatTable({required Size boardSize, required double t}) {
    final theme = widget.seatTheme;
    final diameter = _tableDiameter(boardSize);
    final flat = diameter * theme.tableFit;
    final fade = _isCompleting ? _phase(t, 0.25, 0.6, Curves.easeIn) : 0.0;
    return Positioned(
      left: boardSize.width / 2 - flat / 2,
      top: boardSize.height / 2 + diameter * theme.tableDy - flat / 2,
      width: flat,
      height: flat,
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - fade,
          child: Container(
            decoration: BoxDecoration(
              color: theme.table,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E1E1E), width: 18),
              boxShadow: [
                const BoxShadow(color: MosiColors.ink, spreadRadius: 4),
                BoxShadow(
                  color: theme.deep,
                  offset: const Offset(10, 10),
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stack의 다른 자식은 전부 Positioned/AnimatedPositioned라 "위치 없는" 자식이
  // 하나도 없어야 합니다. 가로 제약이 loose이기 때문에, 여기서 Positioned가
  // 아닌 위젯(SizedBox.shrink() 등)을 반환하면 Stack 전체 너비가 0으로
  // 줄어들어 자리 배치 블록·버튼이 통째로 사라집니다. 그래서 안 보일 때도
  // Opacity로 숨기지, 위젯 자체를 빼지 않습니다.
  Widget _buildTable({required Size boardSize, required double t}) {
    final tableT = _isCompleting
        ? _phase(t, 0.25, 0.6, const Cubic(0.3, 1.4, 0.5, 1))
        : 0.0;
    final diameter = _tableDiameter(boardSize);
    return Positioned(
      left: boardSize.width / 2 - diameter / 2,
      top: boardSize.height / 2 - diameter / 2,
      width: diameter,
      height: diameter,
      child: IgnorePointer(
        child: Opacity(
          opacity: tableT.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.94 + 0.06 * tableT,
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
        ),
      ),
    );
  }

  //=======================태블릿 자리 표시==============================
  /// 시안의 가운데 안내 상자입니다(크림 바탕, 남색 점선).
  ///
  /// 실제 태블릿이 놓이는 자리를 알려 주어, 참가자들이 자기 자리를 태블릿을
  /// 기준으로 맞출 수 있게 합니다. 설정 완료 연출이 시작되면 사라집니다.
  Widget _buildTabletMarker({
    required Size boardSize,
    required _SeatCardMetrics metrics,
    required double t,
  }) {
    // 시안: 앱 기본(300×200)보다 작게 그려 테이블 안에 여유가 보이게 합니다.
    final scale = metrics.size.width / _SeatCardMetrics.large.size.width * 0.58;
    final size = Size(
      _tabletMarkerSize.width * scale,
      _tabletMarkerSize.height * scale,
    );
    final fade = _isCompleting ? _phase(t, 0, 0.35, Curves.easeIn) : 0.0;
    return Positioned(
      left: boardSize.width / 2 - size.width / 2,
      top: boardSize.height / 2 - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - fade,
          child: Transform.scale(
            scale: 1 - 0.1 * fade,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MosiColors.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _DashedRoundedRect(
                color: MosiColors.navy,
                radius: 12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '태블릿',
                          style: MosiFonts.sans(
                            color: MosiColors.muted,
                            size: 15,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '테이블 중앙',
                          style: MosiFonts.sans(
                            color: MosiColors.muted,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    required double chairSize,
    required double t,
  }) {
    final seatCenter = _slotCenterPixel(seatIndex, boardSize, cardSize);
    final delay = _seatDelay(seatIndex);
    final chairT = _isCompleting
        ? _phase(t, delay, 0.55, const Cubic(0.3, 1.4, 0.5, 1))
        : 0.0;
    //=======================의자 방향==============================
    // 의자 이미지는 등받이가 위, 앉는 방향이 아래(+Y, 각도 pi/2)입니다. 자리에서
    // 테이블 중심을 바라보는 각도로 돌려, 어느 자리든 책상을 향해 앉습니다.
    final boardCenter = Offset(boardSize.width / 2, boardSize.height / 2);
    var towardTable = boardCenter - seatCenter;
    if (towardTable.distance < 1) towardTable = const Offset(0, 1);
    final rotation = math.atan2(towardTable.dy, towardTable.dx) - math.pi / 2;
    final chairImage = widget.chairImage;

    return Positioned(
      left: seatCenter.dx - chairSize / 2,
      top: seatCenter.dy - chairSize / 2,
      width: chairSize,
      height: chairSize,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: chairT.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.55 + 0.45 * chairT,
                child: chairImage == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.tableColor,
                            width: 3,
                          ),
                        ),
                        child: SizedBox.expand(
                          child: Icon(
                            Icons.event_seat,
                            color: widget.tableColor,
                            size: 40,
                          ),
                        ),
                      )
                    : Transform.rotate(
                        angle: rotation,
                        child: Image(image: chairImage, fit: BoxFit.contain),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 17.0; y < size.height; y += 34) {
      for (var x = 17.0; x < size.width; x += 34) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CircleRevealClipper extends CustomClipper<Path> {
  const _CircleRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
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
/// 자리 하나를 나타내는 카드입니다(시안 SeatSync).
///
/// 흰 바탕 + 굵은 검은 테두리 + 오프셋 그림자, 왼쪽에 포커페이스 얼굴, 오른쪽에
/// 닉네임. 눌러 고른 카드는 강조색으로 칠하고 살짝 흔들립니다.
class _SeatCard extends StatefulWidget {
  const _SeatCard({
    required this.player,
    required this.seatNumber,
    required this.metrics,
    required this.theme,
    required this.isDragging,
    required this.isSelected,
    this.arrival = 0,
  });

  /// 자리를 옮길 때마다 바뀌는 번호입니다. 바뀌면 도착 반짝임을 한 번 냅니다.
  final int arrival;

  final PlayerLayoutPlayer player;
  final int seatNumber;
  final _SeatCardMetrics metrics;
  final MosiSeatTheme theme;
  final bool isDragging;
  final bool isSelected;

  @override
  State<_SeatCard> createState() => _SeatCardState();
}

class _SeatCardState extends State<_SeatCard> with TickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// 새 자리에 닿을 때 한 번 퍼지는 라임 테두리입니다.
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? _landDelay;

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) _wiggle.repeat();
  }

  @override
  void didUpdateWidget(covariant _SeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arrival != oldWidget.arrival) {
      // 카드가 이동(0.45초)을 거의 마친 뒤에 반짝입니다.
      _landDelay?.cancel();
      _landDelay = Timer(const Duration(milliseconds: 380), () {
        if (mounted) _land.forward(from: 0);
      });
    }
    if (widget.isSelected && !_wiggle.isAnimating) {
      _wiggle.repeat();
    } else if (!widget.isSelected && _wiggle.isAnimating) {
      _wiggle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _landDelay?.cancel();
    _land.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final theme = widget.theme;
    final highlighted = widget.isSelected || widget.isDragging;
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.seatNumber}번 자리 ${widget.player.nickname}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) => Transform.rotate(
            angle: widget.isSelected
                ? 2.5 * math.pi / 180 * math.sin(_wiggle.value * 2 * math.pi)
                : 0,
            child: child,
          ),
          child: AnimatedBuilder(
            animation: _land,
            builder: (context, child) {
              final t = _land.value;
              final glow = t == 0 ? 0.0 : math.sin(t * math.pi);
              return DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(metrics.radius + 2),
                  boxShadow: glow == 0
                      ? null
                      : [
                          BoxShadow(
                            color: MosiColors.lime.withValues(alpha: glow),
                            spreadRadius: 6 * glow,
                          ),
                        ],
                ),
                child: child,
              );
            },
            child: AnimatedScale(
              scale: widget.isDragging ? 1.06 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: metrics.size.width,
                height: metrics.size.height,
                padding: EdgeInsets.symmetric(horizontal: metrics.padding),
                decoration: BoxDecoration(
                  color: highlighted ? theme.selected : MosiColors.white,
                  borderRadius: BorderRadius.circular(metrics.radius),
                  border: Border.all(color: MosiColors.ink, width: 3),
                  boxShadow: [
                    if (highlighted)
                      BoxShadow(color: theme.ring, spreadRadius: 5),
                    BoxShadow(color: theme.deep, offset: const Offset(6, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    MosiFace(
                      characterId: widget.player.characterId,
                      size: metrics.avatar,
                    ),
                    SizedBox(width: metrics.gap),
                    Expanded(
                      child: Text(
                        widget.player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          color: MosiColors.navy,
                          size: metrics.nicknameSize,
                          weight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
