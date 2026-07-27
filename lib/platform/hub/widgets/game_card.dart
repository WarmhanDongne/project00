import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});

  final Map<String, dynamic> game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = game['name']?.toString() ?? '게임 이름';
    final posterUrl = game['posterUrl']?.toString() ?? '';
    final playType = game['playType']?.toString() ?? '';
    final recommendedPlayers = game['recommendedPlayers']?.toString() ?? '';
    final isOwned = game['isOwned'] == true;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: posterUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined, size: 38),
                              SizedBox(height: 6),
                              Text('포스터'),
                            ],
                          ),
                        )
                      : Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 38,
                              ),
                            );
                          },
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: isOwned ? Colors.blue.shade100 : Colors.grey.shade400,
                child: Column(
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (playType.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        playType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (recommendedPlayers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '권장 $recommendedPlayers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
