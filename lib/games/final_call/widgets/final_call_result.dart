import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 가로 결과 화면처럼 중앙에 우승자, 양쪽에 액션을 배치합니다.
class FinalCallResultOverlay extends StatelessWidget {
  const FinalCallResultOverlay({
    super.key,
    required this.winner,
    this.onRestart,
    this.onHome,
    this.showActions = true,
  });

  final FinalCallPlayer? winner;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    const cards = [
      FinalCallCard(id: 'red_10', color: 'red', value: 10),
      FinalCallCard(id: 'blue_10', color: 'blue', value: 10),
      FinalCallCard(id: 'green_10', color: 'green', value: 10),
      FinalCallCard(id: 'yellow_10', color: 'yellow', value: 10),
    ];
    return Material(
      color: const Color(0xFFF7F4EF),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > constraints.maxHeight
                ? 86.0
                : 58.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Assets.games.finalCall.images.background.background
                      .image(fit: BoxFit.cover),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'FINAL CALL',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FinalCallCardView(
                              card: card,
                              width: cardWidth,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _WinnerProfile(imageUrl: winner?.profileImageUrl ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      winner?.nickname ?? 'WINNER',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text('WINNER', style: TextStyle(letterSpacing: 4)),
                  ],
                ),
                if (showActions)
                  Positioned(
                    left: 32,
                    right: 32,
                    bottom: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ResultButton(
                          label: '다시하기',
                          onTap: onRestart,
                          image: Assets
                              .games
                              .finalCall
                              .images
                              .icons
                              .iconAgainBlack,
                        ),
                        _ResultButton(
                          label: '홈으로',
                          onTap: onHome,
                          image:
                              Assets.games.finalCall.images.icons.iconHomeBlack,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WinnerProfile extends StatelessWidget {
  const _WinnerProfile({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFE0E0E0),
      child: Icon(Icons.person, size: 70, color: Colors.black54),
    );
    return ClipOval(
      child: SizedBox(
        width: 112,
        height: 112,
        child: imageUrl.isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _ResultButton extends StatefulWidget {
  const _ResultButton({
    required this.label,
    required this.onTap,
    required this.image,
  });
  final String label;
  final VoidCallback? onTap;
  final AssetGenImage image;

  @override
  State<_ResultButton> createState() => _ResultButtonState();
}

class _ResultButtonState extends State<_ResultButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => pressed = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() => pressed = false);
                widget.onTap?.call();
              },
        child: AnimatedScale(
          scale: pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: widget.image.image(),
          ),
        ),
      ),
    );
  }
}
