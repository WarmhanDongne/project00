import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰에서 게임 우승자를 중앙에 표시하는 결과 다이얼로그입니다.
class PhoneResultDialog extends StatelessWidget {
  const PhoneResultDialog({
    super.key,
    required this.nickname,
    required this.profileImageUrl,
  });

  final String nickname;
  final String profileImageUrl;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 72 : 24,
          vertical: isLandscape ? 12 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isLandscape ? 360 : 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CrownedWinnerProfile(
                  imageUrl: profileImageUrl,
                  size: isLandscape ? 128 : 166,
                ),
                SizedBox(height: isLandscape ? 8 : 14),
                _WinnerText(nickname: nickname, isLandscape: isLandscape),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 프로필 위에 은색 왕관 이미지를 겹쳐 씌운 우승자 표시입니다.
class _CrownedWinnerProfile extends StatelessWidget {
  const _CrownedWinnerProfile({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.42,
      height: size * 1.3,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: _WinnerProfile(imageUrl: imageUrl, size: size),
          ),
          Positioned(
            top: -40,
            child: Assets.games.liarsPoker.images.other.borderCrown.image(
              width: size * 1.3,
              height: size * 0.86,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerProfile extends StatelessWidget {
  const _WinnerProfile({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFF263C31),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.7,
        color: Colors.white70,
      ),
    );

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD9E2DC),
      ),
      child: ClipOval(
        child: imageUrl.trim().isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _WinnerText extends StatelessWidget {
  const _WinnerText({required this.nickname, required this.isLandscape});

  final String nickname;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isLandscape ? 22 : 26,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
          ),
        ),
        SizedBox(height: isLandscape ? 4 : 7),
        Text(
          'WINNER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            color: Colors.white,
            fontSize: isLandscape ? 30 : 38,
            letterSpacing: 2.6,
            shadows: const [Shadow(color: Colors.black, blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}
