import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/games/mafia/screens/mafia_test_screen.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_factory.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class GamePreviewDialog extends StatefulWidget {
  const GamePreviewDialog({
    super.key,
    required this.game,
    required this.roomProvider,
  });

  final GameInfo game;
  final RoomProvider roomProvider;

  @override
  State<GamePreviewDialog> createState() => _GamePreviewDialogState();
}

class _GamePreviewDialogState extends State<GamePreviewDialog> {
  bool _isPlayingVideo = false;
  YoutubePlayerController? _youtubeController;

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
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
    final videoUrl = widget.game.ruleVideoUrl.isEmpty
        ? 'https://www.youtube.com/watch?v=fq4N0hgOWzU' // 테스트 영상
        : widget.game.ruleVideoUrl;
        
    final videoId = _extractVideoId(videoUrl);
    
    if (videoId != null && videoId.isNotEmpty) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
        ),
      );setState(() => _isPlayingVideo = true);
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

  Future<void> _startGame(BuildContext context) async {
    // Mafia UI 개발 중에는 방 인원, 자리 배치, Cloud Function 실행을
    // 모두 건너뛰고 독립된 테스트 화면으로 바로 이동합니다.
    if (widget.game.id == 'mafia') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MafiaTestScreen()),
      );
      return;
    }

    final players = widget.roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final currentPlayerCount = players.length;
    final minPlayers = widget.game.minPlayers > 0 ? widget.game.minPlayers : 2;
    final maxPlayers = widget.game.maxPlayers > 0 ? widget.game.maxPlayers : 6;

    if (widget.game.id.isEmpty) {
      _showMessage(context, '게임 정보를 확인할 수 없습니다.');
      return;
    }

    final templateGame = GameRegistry.find(widget.game.id);
    if (templateGame == null) {
      _showMessage(context, '게임 정보를 확인할 수 없습니다.');
      return;
    }
    final fixedPlayerCount = templateGame.fixedPlayerCount;
    if (fixedPlayerCount != null && currentPlayerCount != fixedPlayerCount) {
      _showMessage(context, '이 게임은 정확히 $fixedPlayerCount명이 필요합니다.');
      return;
    }

    if (currentPlayerCount < minPlayers) {
      _showMessage(context, '이 게임을 시작하려면 최소 $minPlayers명이 필요합니다.');
      return;
    }

    if (currentPlayerCount > maxPlayers) {
      _showMessage(context, '이 게임은 최대 $maxPlayers명까지 플레이할 수 있습니다.');
      return;
    }

    final selected = await widget.roomProvider.selectGame(widget.game.id);
    if (!context.mounted) return;
    if (!selected) {
      _showMessage(
        context,
        widget.roomProvider.errorMessage ?? '게임을 선택하지 못했습니다.',
      );
      return;
    }

    final roomCode = widget.roomProvider.roomCode;
    if (roomCode == null) {
      _showMessage(context, '방 정보를 확인할 수 없습니다.');
      return;
    }

    final initialLayout = PlayerLayoutFactory.create(players);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (layoutContext) => PlayerLayoutEditor(
          initialLayout: initialLayout,
          tableColor: templateGame.tableColor,
          tableBackgroundImage: templateGame.tableBackgroundImage,
          tableImage: templateGame.layoutTableImage,
          chairImage: templateGame.layoutChairImage,
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
    if (_isPlayingVideo && _youtubeController != null) {
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: YoutubePlayer(
                controller: _youtubeController!,
                aspectRatio: 16 / 9,
              ),
            ),
            Positioned(
              right: 20,
              top: 20,
              child: IconButton.filledTonal(
                tooltip: '닫기',
                onPressed: () {
                  setState(() {
                    _isPlayingVideo = false;
                    _youtubeController?.pauseVideo();
                  });
                },
                icon: const Icon(Icons.close, size: 24),
              ),
            ),
          ],
        ),
      );
    }

    final colors = context.platformColors;
    final informationTexts = <String>[
      if (widget.game.playTime > 0) '${widget.game.playTime}분',
      if (_playerCountText().isNotEmpty) _playerCountText(),
    ];
    final activePlayerCount = widget.roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .length;
    final fixedPlayerCount = GameRegistry.find(
      widget.game.id,
    )?.fixedPlayerCount;
    final hasEnoughPlayers = fixedPlayerCount == null
        ? activePlayerCount >= widget.game.minPlayers
        : activePlayerCount == fixedPlayerCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 500),
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
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 240,
                    child: _PosterImage(imageUrl: widget.game.imageUrl),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 42),
                          child: Text(
                            widget.game.name.isEmpty
                                ? '게임 이름'
                                : widget.game.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
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
                        Text(
                          widget.game.description.isEmpty
                              ? '게임 설명이 없습니다.'
                              : widget.game.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _RuleVideoArea(
                            videoUrl: widget.game.ruleVideoUrl,
                            onPlayPressed: _playVideo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!hasEnoughPlayers)
                          PlatformNotice(
                            message: fixedPlayerCount == null
                                ? '현재 인원 $activePlayerCount명은 권장 인원 ${widget.game.minPlayers}~${widget.game.maxPlayers}명과 다릅니다.'
                                : '이 게임은 정확히 $fixedPlayerCount명이 필요합니다. 현재 $activePlayerCount명입니다.',
                            style: PlatformNoticeStyle.warning,
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 140,
                            child: PlatformButton(
                              label: '시작하기',
                              onPressed: () => _startGame(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton.filledTonal(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: colors.surfaceMuted,
        child: imageUrl.isEmpty
            ? Center(
                child: Text(
                  'poster 320×468',
                  style: TextStyle(color: colors.textMuted, fontSize: 10),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
                errorBuilder: (_, _, _) =>
                    Icon(Icons.broken_image_outlined, color: colors.textMuted),
              ),
      ),
    );
  }
}

class _RuleVideoArea extends StatelessWidget {
  const _RuleVideoArea({required this.videoUrl, required this.onPlayPressed});

  final String videoUrl;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return InkWell(
      onTap: onPlayPressed,
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
                videoUrl.isEmpty ? Icons.videocam_off : Icons.play_arrow,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              videoUrl.isEmpty ? '등록된 룰 설명 영상이 없습니다.' : '룰 설명 영상',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
