import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 모시겜 가로형 로고 (심볼 + 워드마크).
///
/// 현재 테마의 밝기에 따라 라이트/다크 버전을 자동으로 고릅니다.
/// 에셋 원본은 `assets/images/logo/`에 있습니다.
class MosigameLogo extends StatelessWidget {
  const MosigameLogo({super.key, this.height = 32});

  /// 로고 높이. 폭은 원본 비율(약 3.93:1)에 맞춰 정해집니다.
  final double height;

  static const _lightAsset = 'assets/images/logo/mosigame_logo.svg';
  static const _darkAsset = 'assets/images/logo/mosigame_logo_dark.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark ? _darkAsset : _lightAsset,
      height: height,
      semanticsLabel: '모시겜',
    );
  }
}
