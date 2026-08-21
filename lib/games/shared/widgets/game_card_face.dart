import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';

/// 카드 원본 이미지(350×512)의 세로/가로 비율입니다.
///
/// 카드 너비에서 높이를 계산하는 모든 연출이 이 값을 씁니다.
const double kCardAspectRatio = 512 / 350;

/// 둥근 모서리·그림자·흰 바탕을 가진 카드 한 장의 공통 몸체입니다.
///
/// 분배·던지기·손패 공개 연출이 같은 DecoratedBox+ClipRRect 조합을 각자
/// 복사해 쓰던 것을 모았습니다. 그림자 세기는 연출마다 다르므로(공중에 뜬
/// 정도 등) 호출부가 [shadow]로 그대로 넘깁니다.
class GameCardFace extends StatelessWidget {
  const GameCardFace({
    super.key,
    required this.asset,
    required this.radius,
    required this.shadow,
    this.backgroundColor = Colors.white,
    this.border,
    this.width,
    this.height,
    this.child,
  });

  final GameImage asset;
  final double radius;
  final BoxShadow shadow;

  /// null이면 바탕을 칠하지 않습니다(카드 이미지가 불투명한 경우).
  final Color? backgroundColor;

  /// 지정하면 이미지 위에 테두리를 겹쳐 그립니다(선택 표시 등).
  final BoxBorder? border;
  final double? width;
  final double? height;

  /// 지정하면 [asset] 대신 이 위젯을 카드 내용으로 씁니다.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: [shadow],
      ),
      foregroundDecoration: border == null
          ? null
          : BoxDecoration(borderRadius: borderRadius, border: border),
      child: ClipRRect(
        borderRadius: borderRadius,
        child:
            child ??
            asset.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
      ),
    );
  }
}
