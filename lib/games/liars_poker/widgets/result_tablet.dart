import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';

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
            asset: Assets.games.liarsPoker.images.cards.whiteA,
            angle: -0.24,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop - 80,
          left: _ResultLayout.cardLeft - 80,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteK,
            angle: -0.1,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop - 30,
          left: _ResultLayout.cardLeft + 120,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteJoker,
            angle: 0.24,
          ),
        ),
        Positioned(
          top: _ResultLayout.cardTop,
          left: _ResultLayout.cardLeft,
          child: _ResultCard(
            asset: Assets.games.liarsPoker.images.cards.finishCard,
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
              shadows: [Shadow(color: Color.fromARGB(255, 0, 0, 0), blurRadius: 8)],
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
          asset: Assets.games.liarsPoker.images.icons.iconAgainBlack,
        ),
        _ResultActionButton(
          action: onExitToLobby,
          label: '나가기',
          asset: Assets.games.liarsPoker.images.icons.iconHomeBlack,
        ),
      ],
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  const _ResultActionButton({
    required this.action,
    required this.label,
    required this.asset,
  });

  final VoidCallback? action;
  final String label;
  final AssetGenImage asset;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(20));

    return Semantics(
      button: true,
      enabled: action != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 220,
          height: 220,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
            color: Color.fromARGB(255, 255, 255, 49),
            borderRadius: borderRadius,
          ),
          child: InkWell(
            onTap: action,
            borderRadius: borderRadius,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: asset.image(
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.asset, this.angle = 0});

  final AssetGenImage asset;
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
