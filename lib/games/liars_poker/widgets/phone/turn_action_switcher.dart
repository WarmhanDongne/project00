import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';

/// 내 턴의 라이어 버튼과 다른 플레이어의 턴 안내를 같은 자리에서 교체합니다.
///
/// 기존 요소는 왼쪽으로 빠지고 새 요소는 오른쪽에서 들어옵니다.
class TurnActionSwitcher extends StatelessWidget {
  const TurnActionSwitcher({
    super.key,
    required this.isRow,
    required this.showLiarButton,
    required this.turnPlayer,
    required this.liarButton,
    required this.height,
    this.alignment = Alignment.center,
    this.profileSize = 100,
    this.nicknameFontSize = 30,
    this.spacing = 10,
  });
  final bool isRow;
  final bool showLiarButton;
  final PhoneGamePlayer? turnPlayer;
  final Widget liarButton;
  final double height;
  final AlignmentGeometry alignment;
  final double profileSize;
  final double nicknameFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final child = _buildCurrentControl();

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: alignment,
              children: [...previousChildren, ?currentChild],
            );
          },
          transitionBuilder: (transitionChild, animation) {
            final isIncoming = transitionChild.key == child.key;
            final offset = isIncoming
                ? Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation)
                : Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: transitionChild),
            );
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildCurrentControl() {
    if (showLiarButton) {
      return KeyedSubtree(
        key: const ValueKey('liar-button'),
        child: liarButton,
      );
    }

    final player = turnPlayer;
    if (player == null) {
      return const SizedBox.shrink(key: ValueKey('turn-player-empty'));
    }

    return TurnPlayerIndicator(
      key: ValueKey('turn-player-${player.uid}'),
      isRow: isRow,
      player: player,
      profileSize: profileSize,
      nicknameFontSize: nicknameFontSize,
      spacing: spacing,
    );
  }
}

/// 현재 턴 플레이어의 프로필과 닉네임을 표시합니다.
class TurnPlayerIndicator extends StatelessWidget {
  const TurnPlayerIndicator({
    super.key,
    required this.isRow,
    required this.player,
    required this.profileSize,
    required this.nicknameFontSize,
    required this.spacing,
  });
  final bool isRow;
  final PhoneGamePlayer player;
  final double profileSize;
  final double nicknameFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final imageUrl = player.profileImageUrl;

    return isRow == true
        //================================가로================================
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(profileSize * 0.2),
                  color: Colors.grey,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          color: Colors.white,
                          size: profileSize * 0.4,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.white,
                        size: profileSize * 0.4,
                      ),
              ),
              SizedBox(width: spacing),
              Flexible(
                child: Text(
                  '${player.nickname}님\n차례입니다',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nicknameFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        //================================세로================================
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(profileSize * 0.2),
                  color: Colors.grey,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          color: Colors.white,
                          size: profileSize * 0.4,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.white,
                        size: profileSize * 0.4,
                      ),
              ),
              SizedBox(width: spacing),
              Flexible(
                child: Text(
                  '${player.nickname}님\n차례입니다',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nicknameFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
  }
}
