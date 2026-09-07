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

  /// Directory path: assets/images/character
  $AssetsImagesCharacterGen get character => const $AssetsImagesCharacterGen();

  /// Directory path: assets/images/others
  $AssetsImagesOthersGen get others => const $AssetsImagesOthersGen();

  /// Directory path: assets/images/patch
  $AssetsImagesPatchGen get patch => const $AssetsImagesPatchGen();

  /// Directory path: assets/images/reconnect
  $AssetsImagesReconnectGen get reconnect => const $AssetsImagesReconnectGen();
}

class $AssetsSoundsGen {
  const $AssetsSoundsGen();

  /// File path: assets/sounds/background.m4a
  String get background =>
      'packages/mosigame_core/assets/sounds/background.m4a';

  /// File path: assets/sounds/dealing.mp3
  String get dealing => 'packages/mosigame_core/assets/sounds/dealing.mp3';

  /// File path: assets/sounds/lever.mp3
  String get lever => 'packages/mosigame_core/assets/sounds/lever.mp3';

  /// File path: assets/sounds/roulette.mp3
  String get roulette => 'packages/mosigame_core/assets/sounds/roulette.mp3';

  /// File path: assets/sounds/stamp.mp3
  String get stamp => 'packages/mosigame_core/assets/sounds/stamp.mp3';

  /// File path: assets/sounds/timer.mp3
  String get timer => 'packages/mosigame_core/assets/sounds/timer.mp3';

  /// List of all assets
  List<String> get values => [
    background,
    dealing,
    lever,
    roulette,
    stamp,
    timer,
  ];
}

class $AssetsImagesCharacterGen {
  const $AssetsImagesCharacterGen();

  /// File path: assets/images/character/bear.webp
  AssetGenImage get bear =>
      const AssetGenImage('assets/images/character/bear.webp');

  /// File path: assets/images/character/bee.webp
  AssetGenImage get bee =>
      const AssetGenImage('assets/images/character/bee.webp');

  /// File path: assets/images/character/cat.webp
  AssetGenImage get cat =>
      const AssetGenImage('assets/images/character/cat.webp');

  /// File path: assets/images/character/crab.webp
  AssetGenImage get crab =>
      const AssetGenImage('assets/images/character/crab.webp');

  /// File path: assets/images/character/deer.webp
  AssetGenImage get deer =>
      const AssetGenImage('assets/images/character/deer.webp');

  /// File path: assets/images/character/elephant.webp
  AssetGenImage get elephant =>
      const AssetGenImage('assets/images/character/elephant.webp');

  /// File path: assets/images/character/frog.webp
  AssetGenImage get frog =>
      const AssetGenImage('assets/images/character/frog.webp');

  /// File path: assets/images/character/giraffe.webp
  AssetGenImage get giraffe =>
      const AssetGenImage('assets/images/character/giraffe.webp');

  /// File path: assets/images/character/hedgehog.webp
  AssetGenImage get hedgehog =>
      const AssetGenImage('assets/images/character/hedgehog.webp');

  /// File path: assets/images/character/kindbear.webp
  AssetGenImage get kindbear =>
      const AssetGenImage('assets/images/character/kindbear.webp');

  /// File path: assets/images/character/octopus.webp
  AssetGenImage get octopus =>
      const AssetGenImage('assets/images/character/octopus.webp');

  /// File path: assets/images/character/owl.webp
  AssetGenImage get owl =>
      const AssetGenImage('assets/images/character/owl.webp');

  /// File path: assets/images/character/penguin.webp
  AssetGenImage get penguin =>
      const AssetGenImage('assets/images/character/penguin.webp');

  /// File path: assets/images/character/rabbit.webp
  AssetGenImage get rabbit =>
      const AssetGenImage('assets/images/character/rabbit.webp');

  /// File path: assets/images/character/shark.webp
  AssetGenImage get shark =>
      const AssetGenImage('assets/images/character/shark.webp');

  /// File path: assets/images/character/snake.webp
  AssetGenImage get snake =>
      const AssetGenImage('assets/images/character/snake.webp');

  /// File path: assets/images/character/whale.webp
  AssetGenImage get whale =>
      const AssetGenImage('assets/images/character/whale.webp');

  /// List of all assets
  List<AssetGenImage> get values => [
    bear,
    bee,
    cat,
    crab,
    deer,
    elephant,
    frog,
    giraffe,
    hedgehog,
    kindbear,
    octopus,
    owl,
    penguin,
    rabbit,
    shark,
    snake,
    whale,
  ];
}

class $AssetsImagesOthersGen {
  const $AssetsImagesOthersGen();

  /// File path: assets/images/others/network_unavailable.webp
  AssetGenImage get networkUnavailable =>
      const AssetGenImage('assets/images/others/network_unavailable.webp');

  /// List of all assets
  List<AssetGenImage> get values => [networkUnavailable];
}

class $AssetsImagesPatchGen {
  const $AssetsImagesPatchGen();

  /// File path: assets/images/patch/.gitkeep
  String get aGitkeep => 'packages/mosigame_core/assets/images/patch/.gitkeep';

  /// File path: assets/images/patch/game_update.webp
  AssetGenImage get gameUpdate =>
      const AssetGenImage('assets/images/patch/game_update.webp');

  /// List of all assets
  List<dynamic> get values => [aGitkeep, gameUpdate];
}

class $AssetsImagesReconnectGen {
  const $AssetsImagesReconnectGen();

  /// File path: assets/images/reconnect/game_controller.webp
  AssetGenImage get gameController =>
      const AssetGenImage('assets/images/reconnect/game_controller.webp');

  /// File path: assets/images/reconnect/star.webp
  AssetGenImage get star =>
      const AssetGenImage('assets/images/reconnect/star.webp');

  /// List of all assets
  List<AssetGenImage> get values => [gameController, star];
}

abstract final class Assets {
  static const String package = 'mosigame_core';

  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsSoundsGen sounds = $AssetsSoundsGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  static const String package = 'mosigame_core';

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

  String get keyName => 'packages/mosigame_core/$_assetName';
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
