import 'package:flutter/material.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// 게임 종료 후 우승자와 다음 동작을 보여주는 태블릿 결과 화면입니다.
class Result extends StatelessWidget {
  const Result({
    super.key,
    this.onRestartGame,
    this.onExitToLobby,
    this.winnerPlayer,
  });

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;
  final PlayerLayoutPlayer? winnerPlayer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: _ResultLayout.canvasWidth,
            height: _ResultLayout.canvasHeight,
            child: _ResultContent(
              winnerPlayer: winnerPlayer,
              onRestartGame: onRestartGame,
              onExitToLobby: onExitToLobby,
            ),
          ),
        ),
      ),
    );
  }
}

/// 모든 기기에서 같은 비율을 유지하기 위한 결과 화면 기준 크기입니다.
abstract final class _ResultLayout {
  static const double canvasWidth = 1194;
  static const double canvasHeight = 834;
  static const double cardWidth = 430;
  static const double cardHeight = 630;
  static const double cardLeft = (canvasWidth - cardWidth) / 2;
  static const double cardTop = (canvasHeight - cardHeight) / 2;
  static const double actionInset = 48;
  static const double actionBottom = 48;
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.winnerPlayer,
    required this.onRestartGame,
    required this.onExitToLobby,
  });

  final PlayerLayoutPlayer? winnerPlayer;
  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: _ResultLayout.cardTop - 30,
          left: _ResultLayout.cardLeft - 120,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteA.game,
            angle: -0.24,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop - 80,
          left: _ResultLayout.cardLeft - 80,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteK.game,
            angle: -0.1,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop - 30,
          left: _ResultLayout.cardLeft + 120,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteJoker.game,
            angle: 0.24,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop,
          left: _ResultLayout.cardLeft,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.finishCard.game,
          ),
        ),
        if (winnerPlayer != null)
          Positioned(
            top: _ResultLayout.cardTop + 310,
            left: _ResultLayout.cardLeft,
            width: _ResultLayout.cardWidth,
            child: _WinnerBadge(player: winnerPlayer!),
          ),
        //==============================다시하기 나가기 버튼트==============================
        Positioned(
          left: _ResultLayout.actionInset,
          right: _ResultLayout.actionInset,
          bottom: _ResultLayout.actionBottom,
          child: _ResultActions(
            onRestartGame: onRestartGame,
            onExitToLobby: onExitToLobby,
          ),
        ),
      ],
    );
  }
}

class _WinnerBadge extends StatelessWidget {
  const _WinnerBadge({required this.player});

  final PlayerLayoutPlayer player;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 132,
            height: 132,
            child: _WinnerProfileImage(imageUrl: player.profileImageUrl),
          ),
        ),
        const SizedBox(height: 40),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              color: Color.fromARGB(255, 8, 2, 2),
              fontSize: 34,
              fontWeight: FontWeight.w200,
              shadows: [
                Shadow(color: Color.fromARGB(255, 0, 0, 0), blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerProfileImage extends StatelessWidget {
  const _WinnerProfileImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _buildFallback();

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return const ColoredBox(
      color: Color(0xffdedede),
      child: Icon(Icons.account_circle, size: 112, color: Colors.grey),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({this.onRestartGame, this.onExitToLobby});

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ResultActionButton(
          action: onRestartGame,
          label: '다시하기',
          asset: Assets.games.liarsPoker.images.button.buttonRetry.game,
        ),
        _ResultActionButton(
          action: onExitToLobby,
          label: '나가기',
          asset: Assets.games.liarsPoker.images.button.buttonHome.game,
        ),
      ],
    );
  }
}

class _ResultActionButton extends StatefulWidget {
  const _ResultActionButton({
    required this.action,
    required this.label,
    required this.asset,
  });

  final VoidCallback? action;
  final String label;
  final GameImage asset;

  @override
  State<_ResultActionButton> createState() => _ResultActionButtonState();
}

class _ResultActionButtonState extends State<_ResultActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.action != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.action == null
            ? null
            : (_) => setState(() => _isPressed = true),
        onTapUp: widget.action == null
            ? null
            : (_) {
                setState(() => _isPressed = false);
                widget.action?.call();
              },
        onTapCancel: widget.action == null
            ? null
            : () => setState(() => _isPressed = false),
        child: AnimatedSlide(
          offset: _isPressed ? const Offset(0, 0.045) : Offset.zero,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _isPressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              width: 220,
              height: 220,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? const Color(0x55000000)
                        : const Color(0x99000000),
                    blurRadius: _isPressed ? 7 : 24,
                    spreadRadius: _isPressed ? 0 : 2,
                    offset: Offset(0, _isPressed ? 3 : 13),
                  ),
                ],
              ),
              child: widget.asset.image(
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.asset, this.angle = 0});

  final GameImage asset;
  final double angle;

  @override
  Widget build(BuildContext context) {
    Widget card = SizedBox(
      width: _ResultLayout.cardWidth,
      height: _ResultLayout.cardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: asset.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (angle != 0) {
      card = Transform.rotate(angle: angle, child: card);
    }

    return card;
  }
}
