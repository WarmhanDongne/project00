import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

class Result extends StatelessWidget {
  const Result({super.key, this.onRestartGame, this.onExitToLobby});

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const cardWidth = 467.0;
    const cardHeight = 684.0;

    final centerLeft = (size.width - cardWidth) / 2;
    final centerTop = (size.height - cardHeight) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: centerTop - 50,
          left: centerLeft - 120,
          child: ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteA,
            angle: -0.3,
            width: cardWidth,
            height: cardHeight,
          ),
        ),

        Positioned(
          top: centerTop - 130,
          left: centerLeft - 80,
          child: ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteK,
            angle: -0.1,
            width: cardWidth,
            height: cardHeight,
          ),
        ),

        Positioned(
          top: centerTop - 50,
          left: centerLeft + 120,
          child: ResultCard(
            asset: Assets.games.liarsPoker.images.cards.whiteJoker,
            angle: 0.3,
            width: cardWidth,
            height: cardHeight,
          ),
        ),

        Positioned(
          top: centerTop,
          left: centerLeft,
          child: ResultCard(
            asset: Assets.games.liarsPoker.images.cards.finishCard,
            width: cardWidth,
            height: cardHeight,
          ),
        ),
        Positioned.fill(
          top: 455,
          child: Center(
            child: Buttons(
              onRestartGame: onRestartGame,
              onExitToLobby: onExitToLobby,
            ),
          ),
        ),
      ],
    );
  }
}

class Buttons extends StatelessWidget {
  const Buttons({super.key, this.onRestartGame, this.onExitToLobby});

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Button(
          action: onRestartGame,
          word: "다시하기",
          asset: Assets.games.liarsPoker.images.icons.iconAgainBlack,
        ),
        SizedBox(width: 500),
        Button(
          action: onExitToLobby,
          word: "나가기",
          asset: Assets.games.liarsPoker.images.icons.iconHomeBlack,
        ),
      ],
    );
  }
}

class Button extends StatelessWidget {
  const Button({
    super.key,
    this.action,
    required this.word,
    required this.asset,
  });
  final AssetGenImage asset;
  final String word;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            spreadRadius: 0,
            offset: Offset(0, 12),
          ),
        ],
        color: const Color.fromARGB(255, 255, 255, 49),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 세로 가운데
        crossAxisAlignment: CrossAxisAlignment.center, // 가로 가운데
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: asset.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          TextButton(
            onPressed: action,
            child: Text(
              word,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.asset,
    this.angle = 0,
    required this.width,
    required this.height,
  });

  final AssetGenImage asset;
  final double angle;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget card = SizedBox(
      width: width,
      height: height,
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
