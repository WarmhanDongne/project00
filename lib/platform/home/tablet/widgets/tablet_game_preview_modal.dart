import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_factory.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_compatibility.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class GamePreviewDialog extends StatefulWidget {
  const GamePreviewDialog({
    super.key,
    required this.game,
    required this.roomProvider,
    this.selectionActive = false,
    this.selection,
  });

  final GameInfo game;
  final RoomProvider roomProvider;
  final bool selectionActive;

  /// 이 미리보기를 띄우면서 함께 보낸 게임 선택 요청입니다.
  ///
  /// 목록은 서버 응답을 기다리지 않고 미리보기를 먼저 띄웁니다. 시작하기와
  /// 닫기는 이 요청이 끝난 뒤에만 진행해야 합니다. 서버는 선택된 게임이 없으면
  /// 자리 배치를 거부하고, 선택 해제가 선택보다 먼저 도착하면 방에 선택이
  /// 남아 버립니다.
  final Future<bool>? selection;

  @override
  State<GamePreviewDialog> createState() => _GamePreviewDialogState();
}

class _GamePreviewDialogState extends State<GamePreviewDialog> {
  bool _isPlayingVideo = false;
  bool _isStarting = false;
  bool _allowPop = false;
  bool _videoControllerClosed = false;
  int _dismissRequestId = 0;
  Future<void>? _dismissFuture;
  Future<bool>? _selectionFuture;
  YoutubePlayerController? _youtubeController;

  @override
  void dispose() {
    _dismissRequestId++;
    _closeVideoController();
    super.dispose();
  }

  void _closeVideoController() {
    if (_videoControllerClosed) return;
    _videoControllerClosed = true;
    _youtubeController?.close();
    _youtubeController = null;
  }

  String? _extractVideoId(String url) {
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    return null;
  }

  void _playVideo() {
    if (widget.game.ruleVideoUrl.isEmpty || _isPlayingVideo) return;
    final videoId = _extractVideoId(widget.game.ruleVideoUrl);

    if (videoId != null && videoId.isNotEmpty) {
      _videoControllerClosed = false;
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
        ),
      );
      setState(() => _isPlayingVideo = true);
    } else {
      _showMessage(context, '유효하지 않은 영상 주소입니다.');
    }
  }

  String _playerCountText() {
    final fixedPlayerCount = GameRegistry.find(
      widget.game.id,
    )?.fixedPlayerCount;
    if (fixedPlayerCount != null) return '플레이 인원 $fixedPlayerCount명';
    if (widget.game.minPlayers > 0 && widget.game.maxPlayers > 0) {
      return '플레이 인원 ${widget.game.minPlayers}~${widget.game.maxPlayers}명';
    }
    if (widget.game.minPlayers > 0) {
      return '최소 ${widget.game.minPlayers}명';
    }
    if (widget.game.maxPlayers > 0) {
      return '최대 ${widget.game.maxPlayers}명';
    }
    return '';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 함께 보낸 게임 선택 요청이 끝나기를 기다립니다(여러 번 불러도 한 번만).
  Future<bool> _awaitSelection() {
    if (!widget.selectionActive) return Future.value(true);
    return _selectionFuture ??= widget.selection ?? Future.value(true);
  }

  Future<void> _dismiss() {
    final inFlight = _dismissFuture;
    if (inFlight != null) return inFlight;

    final requestId = ++_dismissRequestId;
    final future = _performDismiss(requestId);
    _dismissFuture = future;
    return future;
  }

  Future<void> _performDismiss(int requestId) async {
    if (!mounted) return;
    // 서버 응답을 기다리지 않고 바로 닫습니다. 방의 선택을 해제하는 호출은
    // 미리보기를 띄운 목록 화면이 이어받습니다(선택이 서버에 닿은 뒤에 보내야
    // 하고, 실패를 알릴 화면도 남아 있어야 합니다).
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _dismissRequestId) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    // true는 '사용자가 닫았으니 선택을 해제해 달라'는 뜻입니다. 시작하기로
    // 넘어가면 이 경로를 지나지 않아 선택이 유지됩니다.
    Navigator.of(context).pop(true);
  }

  void _handleBack() {
    unawaited(_dismiss());
  }

  Future<void> _startGame() async {
    final players = widget.roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final currentPlayerCount = players.length;
    final minPlayers = widget.game.minPlayers > 0 ? widget.game.minPlayers : 2;
    final maxPlayers = widget.game.maxPlayers > 0
        ? widget.game.maxPlayers
        : RoomLimits.defaultMaxPlayers;

    if (widget.game.id.isEmpty) {
      _showMessage(context, '게임 정보를 확인할 수 없습니다.');
      return;
    }

    // 스토어 배포 후 서버에 추가된 게임은 이 빌드에 코드가 없을 수 있습니다.
    // 시작 지점 한 곳에서 막고 업데이트를 안내합니다.
    if (!isGamePlayableOnThisBuild(widget.game)) {
      _showMessage(context, gameRequiresUpdateMessage);
      return;
    }
    final templateGame = GameRegistry.find(widget.game.id);
    if (templateGame == null) {
      _showMessage(context, gameRequiresUpdateMessage);
      return;
    }
    final fixedPlayerCount = templateGame.fixedPlayerCount;
    if (fixedPlayerCount != null && currentPlayerCount != fixedPlayerCount) {
      _showMessage(
        context,
        '이 게임은 $fixedPlayerCount명이 모이면 시작할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    if (currentPlayerCount < minPlayers) {
      _showMessage(
        context,
        '이 게임은 최소 $minPlayers명부터 시작할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    if (currentPlayerCount > maxPlayers) {
      _showMessage(
        context,
        '이 게임은 최대 $maxPlayers명까지 함께할 수 있어요. '
        '현재 $currentPlayerCount명이 참여 중입니다.',
      );
      return;
    }

    final roomCode = widget.roomProvider.roomCode;
    if (roomCode == null) {
      _showMessage(context, '방 정보를 확인할 수 없습니다.');
      return;
    }

    setState(() => _isStarting = true);
    // 서버는 선택된 게임이 없으면 자리 배치를 거부합니다. 사용자가 응답보다
    // 빨리 눌렀다면 여기서만 잠깐 기다립니다.
    if (!await _awaitSelection()) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      _showMessage(
        context,
        widget.roomProvider.errorMessage ?? '게임을 선택하지 못했습니다.',
      );
      // 방에 선택이 남지 않았으므로 미리보기를 닫아 다시 고르게 합니다.
      unawaited(_dismiss());
      return;
    }
    if (!mounted) return;
    final seatingStarted = await widget.roomProvider.beginPlayerSeating();
    if (!mounted) return;
    if (!seatingStarted) {
      setState(() => _isStarting = false);
      _showMessage(
        context,
        widget.roomProvider.errorMessage ?? '자리 배치를 시작하지 못했습니다.',
      );
      return;
    }
    final lockedPlayers = widget.roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final initialLayout = PlayerLayoutFactory.create(lockedPlayers);

    //================상태바 표시=================
    // 게임 선택 직후 자리 배치 화면부터 실제 게임과 같은 전체 화면을 유지합니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (layoutContext) => _buildStartSetup(
          layoutContext,
          templateGame: templateGame,
          initialLayout: initialLayout,
          roomCode: roomCode,
        ),
      ),
    );
  }

  /// 자리 배치 화면 자리에 무엇을 띄울지 정합니다.
  ///
  /// 게임이 자기만의 준비 화면을 주면([TemplateGame.buildStartSetupScreen])
  /// 그것을 띄우고, 없으면 공용 자리 배치를 띄웁니다. 게임 id로 분기하지
  /// 않으므로 게임을 추가할 때 이 파일은 손대지 않습니다.
  Widget _buildStartSetup(
    BuildContext layoutContext, {
    required TemplateGame templateGame,
    required PlayerLayoutModel initialLayout,
    required String roomCode,
  }) {
    Future<bool> cancel() async {
      final cleared = await widget.roomProvider.clearSelectedGame();
      if (!layoutContext.mounted) return false;
      if (!cleared) {
        _showMessage(
          layoutContext,
          widget.roomProvider.errorMessage ?? '게임 선택을 해제하지 못했습니다.',
        );
      }
      return cleared;
    }

    Future<bool> prepare(
      PlayerLayoutModel completedLayout, {
      Map<String, Object?>? options,
    }) async {
      //자리 realtime database에 저장
      final saved = await widget.roomProvider.savePlayerSeatIndexes({
        for (final player in completedLayout.players)
          player.uid: player.seatIndex,
      });
      if (!layoutContext.mounted) return false;
      if (!saved) {
        _showMessage(
          layoutContext,
          widget.roomProvider.errorMessage ?? '플레이어 자리를 저장하지 못했습니다.',
        );
        return false;
      }

      try {
        await templateGame.startGame(roomCode, options: options);
      } catch (error) {
        if (!layoutContext.mounted) return false;
        _showMessage(layoutContext, '게임을 시작하지 못했습니다.\n$error');
        return false;
      }
      return layoutContext.mounted;
    }

    void complete(PlayerLayoutModel completedLayout) {
      if (!layoutContext.mounted) return;
      //=======================태블릿 게임 방향 불변 조건==============================
      // 모든 태블릿 게임은 게임별 휴대폰 정책과 관계없이 항상 가로입니다.
      unawaited(AppOrientation.lockTabletGameLandscape());
      // 자리 배치 연출이 화면을 게임 배경색으로 가득 채운 채로 끝나므로,
      // 여기서 슬라이드·페이드 같은 전환 효과를 주면 오히려 화면이
      // 바뀌었다는 느낌이 들어 연출이 끊겨 보입니다. 전환 없이 즉시
      // 바꿔서 하나의 연출처럼 이어지게 합니다.
      Navigator.of(layoutContext).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => templateGame.buildTabletScreen(
            playerLayout: completedLayout,
            provider: widget.roomProvider,
            roomCode: roomCode,
          ),
        ),
      );
    }

    return templateGame.buildStartSetupScreen(
          layout: initialLayout,
          onPrepare: prepare,
          onComplete: complete,
          onCancel: cancel,
        ) ??
        PlayerLayoutEditor(
          initialLayout: initialLayout,
          tableColor: templateGame.tableColor,
          tableBackgroundImage: templateGame.tableBackgroundImage,
          tableImage: templateGame.layoutTableImage,
          chairImage: templateGame.layoutChairImage,
          onCancel: cancel,
          onPrepare: prepare,
          onComplete: complete,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final informationTexts = <String>[
      if (widget.game.playTime > 0) '${widget.game.playTime}분',
      if (_playerCountText().isNotEmpty) _playerCountText(),
    ];
    final activePlayerCount = widget.roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .length;
    final templateGame = GameRegistry.find(widget.game.id);
    final fixedPlayerCount = templateGame?.fixedPlayerCount;
    final minPlayers = widget.game.minPlayers > 0 ? widget.game.minPlayers : 2;
    final warningMessage =
        fixedPlayerCount != null && activePlayerCount != fixedPlayerCount
        ? '이 게임은 $fixedPlayerCount명이 모이면 시작할 수 있어요. '
              '현재 $activePlayerCount명이 참여 중입니다.'
        : fixedPlayerCount == null && activePlayerCount < minPlayers
        ? '이 게임은 최소 $minPlayers명부터 시작할 수 있어요. '
              '현재 $activePlayerCount명이 참여 중입니다.'
        : null;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.game.name.isEmpty ? '게임 이름' : widget.game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: '닫기',
                        onPressed: _isStarting
                            ? null
                            : () => unawaited(_dismiss()),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final text in informationTexts)
                        PlatformTag(label: text),
                      for (final genre in widget.game.genres.take(3))
                        PlatformTag(label: genre, highlighted: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.game.effectiveTabletDescription.isEmpty
                                  ? '게임 설명이 없습니다.'
                                  : widget.game.effectiveTabletDescription,
                              maxLines: 7,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: _ComponentArtwork(
                                url: widget.game.componentImageUrl,
                                fallback:
                                    templateGame?.buildTabletPreviewArtwork() ??
                                    const _UnavailablePreviewArtwork(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _RuleVideoArea(
                                videoUrl: widget.game.ruleVideoUrl,
                                controller: _youtubeController,
                                isPlaying: _isPlayingVideo,
                                onPlayPressed: _playVideo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (warningMessage != null) ...[
                                  Expanded(
                                    child: PlatformNotice(
                                      message: warningMessage,
                                      style: PlatformNoticeStyle.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ] else
                                  const Spacer(),
                                SizedBox(
                                  width: 140,
                                  child: PlatformButton(
                                    label: '시작하기',
                                    loading: _isStarting,
                                    onPressed: _isStarting ? null : _startGame,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 게임 구성품 사진입니다(Firestore `componentImageUrl`).
///
/// 서버 그림을 우선 보여 주고, **주소가 비었거나 내려받기가 실패하면**
/// 게임이 코드로 그리는 미리보기를 그대로 씁니다. 내려받는 동안에도 코드 그림을
/// 띄워 두므로 모달이 빈 칸으로 뜨는 순간이 없습니다.
///
/// 그림은 구성품을 늘어놓은 사진이라 잘리면 안 됩니다. 그래서 칸을 채우지 않고
/// [BoxFit.contain]으로 전체가 보이게 넣습니다.
class _ComponentArtwork extends StatelessWidget {
  const _ComponentArtwork({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      // 구성품 사진은 어두운 배경 위에 찍혀 있습니다. 4:3보다 넓은 사진이 오면
      // 위아래에 띠가 생기는데, 검정 위에 두면 사진과 이어져 보입니다.
      child: ColoredBox(
        color: Colors.black,
        child: Image.network(
          url,
          key: const Key('game-component-artwork'),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _UnavailablePreviewArtwork extends StatelessWidget {
  const _UnavailablePreviewArtwork();

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return ClipRRect(
      key: const Key('unknown-game-preview-artwork'),
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: colors.surfaceMuted,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.extension_outlined, color: colors.textMuted, size: 34),
              const SizedBox(height: 8),
              Text(
                '게임 구성 요소를 준비 중입니다.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleVideoArea extends StatelessWidget {
  const _RuleVideoArea({
    required this.videoUrl,
    required this.controller,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  final String videoUrl;
  final YoutubePlayerController? controller;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    if (isPlaying && controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: ColoredBox(
          color: Colors.black,
          child: YoutubePlayer(controller: controller!),
        ),
      );
    }
    final hasVideo = videoUrl.isNotEmpty;
    return InkWell(
      onTap: hasVideo ? onPlayPressed : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 90),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.surface,
              child: Icon(
                hasVideo ? Icons.play_arrow : Icons.videocam_off,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasVideo ? '룰 설명 영상' : '등록된 룰 설명 영상이 없습니다.',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
