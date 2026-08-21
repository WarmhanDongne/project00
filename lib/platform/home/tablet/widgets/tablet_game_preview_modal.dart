import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_factory.dart';
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
  });

  final GameInfo game;
  final RoomProvider roomProvider;
  final bool selectionActive;

  @override
  State<GamePreviewDialog> createState() => _GamePreviewDialogState();
}

class _GamePreviewDialogState extends State<GamePreviewDialog> {
  bool _isPlayingVideo = false;
  bool _isClosing = false;
  bool _isStarting = false;
  bool _allowPop = false;
  bool _videoControllerClosed = false;
  int _dismissRequestId = 0;
  Future<void>? _dismissFuture;
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
    setState(() => _isClosing = true);

    final cleared =
        !widget.selectionActive ||
        await widget.roomProvider.clearSelectedGame();
    if (!mounted || requestId != _dismissRequestId) return;
    if (!cleared) {
      setState(() => _isClosing = false);
      _dismissFuture = null;
      _showMessage(
        context,
        widget.roomProvider.errorMessage ?? '게임 선택을 해제하지 못했습니다.',
      );
      return;
    }

    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _dismissRequestId) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop();
  }

  void _handleBack() {
    unawaited(_dismiss());
  }

  Future<void> _startGame(BuildContext context) async {
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

    final initialLayout = PlayerLayoutFactory.create(players);

    setState(() => _isStarting = true);
    //================상태바 표시=================
    // 게임 선택 직후 자리 배치 화면부터 실제 게임과 같은 전체 화면을 유지합니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (layoutContext) => PlayerLayoutEditor(
          initialLayout: initialLayout,
          tableColor: templateGame.tableColor,
          tableBackgroundImage: templateGame.tableBackgroundImage,
          tableImage: templateGame.layoutTableImage,
          chairImage: templateGame.layoutChairImage,
          onCancel: () async {
            final cleared = await widget.roomProvider.clearSelectedGame();
            if (!layoutContext.mounted) return false;
            if (!cleared) {
              _showMessage(
                layoutContext,
                widget.roomProvider.errorMessage ?? '게임 선택을 해제하지 못했습니다.',
              );
            }
            return cleared;
          },
          onPrepare: (completedLayout) async {
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
              await templateGame.startGame(roomCode);
            } catch (error) {
              if (!layoutContext.mounted) return false;
              _showMessage(layoutContext, '게임을 시작하지 못했습니다.\n$error');
              return false;
            }
            return layoutContext.mounted;
          },
          onComplete: (completedLayout) {
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
          },
        ),
      ),
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
                        onPressed: _isClosing || _isStarting
                            ? null
                            : () => unawaited(_dismiss()),
                        icon: _isClosing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.close, size: 20),
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
                              child:
                                  templateGame?.buildTabletPreviewArtwork() ??
                                  const _UnavailablePreviewArtwork(),
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
                                    onPressed: _isClosing || _isStarting
                                        ? null
                                        : () => _startGame(context),
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
