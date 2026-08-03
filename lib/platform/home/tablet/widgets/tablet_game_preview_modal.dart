import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/models/player_layout_factory.dart';
import 'package:project00/games/liars_poker/screens/liars_poker.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/platform/home/models/game_info.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_button.dart';

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
    final members = roomProvider.members
        .where((member) => member.isActive && member.isPlayer)
        .toList(growable: false);
    final currentPlayerCount = members.length;
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

    final initialLayout = PlayerLayoutFactory.create(members);

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

            Navigator.of(layoutContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LiarsPoker(playerLayout: completedLayout),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final informationTexts = <String>[
      if (game.playTime > 0) '플레이 시간 ${game.playTime}분',
      if (_playerCountText().isNotEmpty) _playerCountText(),
      if (game.genresText.isNotEmpty) game.genresText,
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 520),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(color: Color(0xff969696)),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 230,
                    child: _PosterImage(imageUrl: game.imageUrl),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name.isEmpty ? '게임 이름' : game.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 33,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (informationTexts.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: [
                                for (final text in informationTexts)
                                  _GameInformationChip(text: text),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                game.description.isEmpty
                                    ? '게임 설명이 없습니다.'
                                    : game.description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RuleVideoArea(videoUrl: game.ruleVideoUrl),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              text: '시작하기',
                              // text: isOwned ? '시작하기' : '구매 필요',
                              width: 140,
                              height: 48,
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                              onPressed: () {
                                _startGame(context);
                              },
                              // onPressed: isOwned
                              // ? () => _startGame(context)
                              // : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: -14,
                top: -14,
                child: IconButton(
                  tooltip: '닫기',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, size: 30, color: Colors.white),
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
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 52, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('준비중'),
                ],
              ),
            )
          : Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 52,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text('이미지를 불러올 수 없습니다.', textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _GameInformationChip extends StatelessWidget {
  const _GameInformationChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Colors.grey.shade300,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black),
      ),
    );
  }
}

class _RuleVideoArea extends StatelessWidget {
  const _RuleVideoArea({required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: videoUrl.isEmpty
          ? null
          : () {
              debugPrint('룰 설명 영상 URL: $videoUrl');

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('룰 영상 주소: $videoUrl')));
            },
      child: Container(
        width: double.infinity,
        height: 125,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              videoUrl.isEmpty
                  ? Icons.videocam_off_outlined
                  : Icons.play_circle_outline,
              size: 42,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 6),
            Text(videoUrl.isEmpty ? '등록된 룰 설명 영상이 없습니다.' : '룰 설명 영상'),
          ],
        ),
      ),
    );
  }
}
