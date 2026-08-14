import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/tablet_game.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/liars_poker/models/player_layout_factory.dart';
import 'package:project00/games/liars_poker/screens/liars_poker.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/mafia/screens/mafia_test_screen.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class GamePreviewDialog extends StatelessWidget {
  const GamePreviewDialog({
    super.key,
    required this.game,
    required this.roomProvider,
  });

  final GameInfo game;
  final RoomProvider roomProvider;

  String _playerCountText() {
    if (game.minPlayers > 0 && game.maxPlayers > 0) {
      return '플레이 인원 ${game.minPlayers}~${game.maxPlayers}명';
    }
    if (game.minPlayers > 0) {
      return '최소 ${game.minPlayers}명';
    }
    if (game.maxPlayers > 0) {
      return '최대 ${game.maxPlayers}명';
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
    if (game.id == 'mafia') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MafiaTestScreen()),
      );
      return;
    }

    final players = roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .toList(growable: false);
    final currentPlayerCount = players.length;
    final minPlayers = game.minPlayers > 0 ? game.minPlayers : 2;
    final maxPlayers = game.maxPlayers > 0 ? game.maxPlayers : 6;

    if (currentPlayerCount < minPlayers) {
      _showMessage(context, '이 게임을 시작하려면 최소 $minPlayers명이 필요합니다.');
      return;
    }

    if (currentPlayerCount > maxPlayers) {
      _showMessage(context, '이 게임은 최대 $maxPlayers명까지 플레이할 수 있습니다.');
      return;
    }

    if (game.id.isEmpty) {
      _showMessage(context, '게임 정보를 확인할 수 없습니다.');
      return;
    }

    final selected = await roomProvider.selectGame(game.id);
    if (!context.mounted) return;
    if (!selected) {
      _showMessage(context, roomProvider.errorMessage ?? '게임을 선택하지 못했습니다.');
      return;
    }

    final initialLayout = PlayerLayoutFactory.create(players);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (layoutContext) => PlayerLayoutEditor(
          initialLayout: initialLayout,
          onComplete: (completedLayout) async {
            //자리 realtime database에 저장
            final saved = await roomProvider.savePlayerSeatIndexes({
              for (final player in completedLayout.players)
                player.uid: player.seatIndex,
            });
            if (!layoutContext.mounted) return;
            if (!saved) {
              _showMessage(
                layoutContext,
                roomProvider.errorMessage ?? '플레이어 자리를 저장하지 못했습니다.',
              );
              return;
            }

            final roomCode = roomProvider.roomCode;
            if (roomCode == null) {
              _showMessage(layoutContext, '방 정보를 확인할 수 없습니다.');
              return;
            }

            if (game.id == 'final_call') {
              final finalCallService = FinalCallService();
              try {
                await finalCallService.command.startGame(roomCode: roomCode);
              } catch (error) {
                if (!layoutContext.mounted) return;
                _showMessage(layoutContext, '게임을 시작하지 못했습니다.\n$error');
                return;
              }
              if (!layoutContext.mounted) return;
              Navigator.of(layoutContext).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => FinalCallTabletGameEntry(
                    roomCode: roomCode,
                    gameService: finalCallService,
                    provider: roomProvider,
                  ),
                ),
              );
              return;
            }

            final gameService = LiarsPokerService();
            try {
              await gameService.command.startGame(roomCode: roomCode);
            } catch (error) {
              if (!layoutContext.mounted) return;
              _showMessage(layoutContext, '게임을 시작하지 못했습니다.\n$error');
              return;
            }
            if (!layoutContext.mounted) return;
            Navigator.of(layoutContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LiarsPoker(
                  playerLayout: completedLayout,
                  provider: roomProvider,
                  roomCode: roomCode,
                  gameService: gameService,
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
      if (game.playTime > 0) '${game.playTime}분',
      if (_playerCountText().isNotEmpty) _playerCountText(),
    ];
    final activePlayerCount = roomProvider.players
        .where((player) => player.isActive && player.isPlayer)
        .length;
    final hasEnoughPlayers = activePlayerCount >= game.minPlayers;

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
                    child: _PosterImage(imageUrl: game.imageUrl),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 42),
                          child: Text(
                            game.name.isEmpty ? '게임 이름' : game.name,
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
                            for (final genre in game.genres.take(3))
                              PlatformTag(label: genre, highlighted: true),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          game.description.isEmpty
                              ? '게임 설명이 없습니다.'
                              : game.description,
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
                          child: _RuleVideoArea(videoUrl: game.ruleVideoUrl),
                        ),
                        const SizedBox(height: 10),
                        if (!hasEnoughPlayers)
                          PlatformNotice(
                            message:
                                '현재 인원 $activePlayerCount명은 권장 인원 ${game.minPlayers}~${game.maxPlayers}명보다 적습니다.',
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
  const _RuleVideoArea({required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return InkWell(
      onTap: videoUrl.isEmpty
          ? null
          : () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('룰 영상 주소: $videoUrl')));
            },
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
