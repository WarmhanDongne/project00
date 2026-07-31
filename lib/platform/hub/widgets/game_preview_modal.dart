import 'package:flutter/material.dart';
import 'package:project00/platform/hub/providers/room_provider.dart';
import 'package:project00/platform/hub/services/room_service.dart';
import 'package:project00/platform/hub/widgets/button.dart';
import 'package:project00/shared/player_layouts/player_layout.dart';

class GamePreviewDialog extends StatelessWidget {
  const GamePreviewDialog({
    super.key,
    required this.game,
    required this.roomProvider,
  });

  final Map<String, dynamic> game;
  final RoomProvider roomProvider;

  String _stringValue(String key) {
    final value = game[key];

    if (value == null) {
      return '';
    }
    return value.toString();
  }
  int? _nullableIntValue(String key) {
    final value = game[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _playerCountText() {
    final minPlayers = _nullableIntValue('minPlayers');
    final maxPlayers = _nullableIntValue('maxPlayers');
    final recommendedPlayers = _stringValue('recommendedPlayers');

    if (recommendedPlayers.isNotEmpty) {
      return '권장 인원 $recommendedPlayers';
    }
    if (minPlayers != null && maxPlayers != null) {
      return '플레이 인원 $minPlayers~$maxPlayers명';
    }
    if (minPlayers != null) {
      return '최소 $minPlayers명';
    }
    if (maxPlayers != null) {
      return '최대 $maxPlayers명';
    }
    return '';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startGame(BuildContext context) {
    final members = List<RoomMember>.from(roomProvider.members);
    final currentPlayerCount = members.length;
    // final minPlayers = _nullableIntValue('minPlayers') ?? 2;
    final maxPlayers = _nullableIntValue('maxPlayers') ?? 6;

    if (!roomProvider.isInRoom) {
      _showMessage(context, '방 정보를 불러오는 중입니다.');
      return;
    }

    // if (currentPlayerCount < minPlayers) {
    //   _showMessage(context, '이 게임을 시작하려면 최소 $minPlayers명이 필요합니다.');
    //   return;
    // }

    if (currentPlayerCount > maxPlayers) {
      _showMessage(context, '이 게임은 최대 $maxPlayers명까지 플레이할 수 있습니다.');
      return;
    }

    // 현재 모달 경로를 PlayerSlots 경로로 교체합니다.
    // pop 후 같은 context를 사용하는 문제를 피할 수 있습니다.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlayerSlots(players: members)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameName = _stringValue('name');
    final posterUrl = _stringValue('posterUrl');
    final playType = _stringValue('playType');
    final genre = _stringValue('genre');
    final description = _stringValue('description');
    final worldDescription = _stringValue('worldDescription');
    final ruleVideoUrl = _stringValue('ruleVideoUrl');
    // final isOwned = game['isOwned'] == true;

    final informationTexts = <String>[
      if (playType.isNotEmpty) playType,
      if (_playerCountText().isNotEmpty) _playerCountText(),
      if (genre.isNotEmpty) genre,
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
                    child: _PosterImage(imageUrl: posterUrl),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gameName.isEmpty ? '게임 이름' : gameName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
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
                          if (worldDescription.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              worldDescription,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                description.isEmpty
                                    ? '게임 설명이 없습니다.'
                                    : description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RuleVideoArea(videoUrl: ruleVideoUrl),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              text:'시작하기',
                              // text: isOwned ? '시작하기' : '구매 필요',
                              width: 140,
                              height: 48,
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                              onPressed: () => _startGame(context),
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
