import 'package:flutter/widgets.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================게임 이미지 핸들==============================
/// 게임 화면이 쓰는 이미지 단위입니다. `Assets....game`으로 만듭니다.
///
/// [AssetGenImage.image]와 같은 API를 제공하되, 실제 이미지는
/// [GameAssetStore]가 해석합니다. 그래서 게임 리소스를 서버에서 내려받는
/// 구조로 바꿔도 게임 화면 코드는 수정할 필요가 없습니다.
///
/// 기본값([gaplessPlayback] true, [filterQuality] medium 등)은 기존
/// [AssetGenImage.image]와 동일하게 맞춰 화면이 달라지지 않게 했습니다.
@immutable
class GameImage {
  const GameImage.bundled(this._bundled);

  final AssetGenImage _bundled;

  /// 번들 기준 에셋 경로입니다. 위젯 key나 로그 식별자로 씁니다.
  String get path => _bundled.path;

  ImageProvider provider() =>
      GameAssetStore.instance.imageProviderFor(_bundled);

  Image image({
    Key? key,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    return Image(
      key: key,
      image: provider(),
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      filterQuality: filterQuality,
    );
  }

  /// 손패 비교(_sameCardAssets)나 위젯 key처럼 값으로 비교하는 곳이 있어
  /// 같은 에셋이면 같은 값으로 취급합니다.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameImage && other._bundled.path == _bundled.path;

  @override
  int get hashCode => _bundled.path.hashCode;
}

extension GameImageX on AssetGenImage {
  /// 게임 코드에서 이미지를 쓸 때의 표준 진입점입니다.
  GameImage get game => GameImage.bundled(this);
}

extension GameImageListX on List<AssetGenImage> {
  /// `Assets....values`처럼 생성된 목록을 한 번에 변환합니다.
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) GameImage.bundled(asset)]);
}
