// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// Directory path: assets/images/phone_result
  $AssetsImagesPhoneResultGen get phoneResult =>
      const $AssetsImagesPhoneResultGen();

  /// Directory path: assets/images/widgets
  $AssetsImagesWidgetsGen get widgets => const $AssetsImagesWidgetsGen();
}

class $AssetsImagesPhoneResultGen {
  const $AssetsImagesPhoneResultGen();

  /// File path: assets/images/phone_result/border_crown.webp
  AssetGenImage get borderCrown =>
      const AssetGenImage('assets/images/phone_result/border_crown.webp');

  /// List of all assets
  List<AssetGenImage> get values => [borderCrown];
}

class $AssetsImagesWidgetsGen {
  const $AssetsImagesWidgetsGen();

  /// Directory path: assets/images/widgets/roulette
  $AssetsImagesWidgetsRouletteGen get roulette =>
      const $AssetsImagesWidgetsRouletteGen();
}

class $AssetsImagesWidgetsRouletteGen {
  const $AssetsImagesWidgetsRouletteGen();

  /// File path: assets/images/widgets/roulette/border.webp
  AssetGenImage get border =>
      const AssetGenImage('assets/images/widgets/roulette/border.webp');

  /// File path: assets/images/widgets/roulette/centerStone.webp
  AssetGenImage get centerStone =>
      const AssetGenImage('assets/images/widgets/roulette/centerStone.webp');

  /// File path: assets/images/widgets/roulette/lever_bottom.webp
  AssetGenImage get leverBottom =>
      const AssetGenImage('assets/images/widgets/roulette/lever_bottom.webp');

  /// File path: assets/images/widgets/roulette/lever_head.webp
  AssetGenImage get leverHead =>
      const AssetGenImage('assets/images/widgets/roulette/lever_head.webp');

  /// File path: assets/images/widgets/roulette/lever_stick.webp
  AssetGenImage get leverStick =>
      const AssetGenImage('assets/images/widgets/roulette/lever_stick.webp');

  /// File path: assets/images/widgets/roulette/pointer.webp
  AssetGenImage get pointer =>
      const AssetGenImage('assets/images/widgets/roulette/pointer.webp');

  /// List of all assets
  List<AssetGenImage> get values => [
    border,
    centerStone,
    leverBottom,
    leverHead,
    leverStick,
    pointer,
  ];
}

abstract final class Assets {
  static const String package = 'game_kit';

  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  static const String package = 'game_kit';

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
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
    @Deprecated('Do not specify package for a generated library asset')
    String? package = package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
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
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    @Deprecated('Do not specify package for a generated library asset')
    String? package = package,
  }) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => 'packages/game_kit/$_assetName';
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
