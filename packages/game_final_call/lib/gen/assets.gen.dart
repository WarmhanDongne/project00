// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsGamesGen {
  const $AssetsGamesGen();

  /// Directory path: assets/games/final_call
  $AssetsGamesFinalCallGen get finalCall => const $AssetsGamesFinalCallGen();
}

class $AssetsGamesFinalCallGen {
  const $AssetsGamesFinalCallGen();

  /// Directory path: assets/games/final_call/animations
  $AssetsGamesFinalCallAnimationsGen get animations =>
      const $AssetsGamesFinalCallAnimationsGen();

  /// Directory path: assets/games/final_call/images
  $AssetsGamesFinalCallImagesGen get images =>
      const $AssetsGamesFinalCallImagesGen();

  /// Directory path: assets/games/final_call/sounds
  $AssetsGamesFinalCallSoundsGen get sounds =>
      const $AssetsGamesFinalCallSoundsGen();
}

class $AssetsGamesFinalCallAnimationsGen {
  const $AssetsGamesFinalCallAnimationsGen();

  /// File path: assets/games/final_call/animations/.gitkeep
  String get aGitkeep =>
      'packages/game_final_call/assets/games/final_call/animations/.gitkeep';

  /// List of all assets
  List<String> get values => [aGitkeep];
}

class $AssetsGamesFinalCallImagesGen {
  const $AssetsGamesFinalCallImagesGen();

  /// Directory path: assets/games/final_call/images/modal
  $AssetsGamesFinalCallImagesModalGen get modal =>
      const $AssetsGamesFinalCallImagesModalGen();
}

class $AssetsGamesFinalCallSoundsGen {
  const $AssetsGamesFinalCallSoundsGen();

  /// File path: assets/games/final_call/sounds/.gitkeep
  String get aGitkeep =>
      'packages/game_final_call/assets/games/final_call/sounds/.gitkeep';

  /// File path: assets/games/final_call/sounds/heartbreak.mp3
  String get heartbreak =>
      'packages/game_final_call/assets/games/final_call/sounds/heartbreak.mp3';

  /// File path: assets/games/final_call/sounds/voice_call.m4a
  String get voiceCall =>
      'packages/game_final_call/assets/games/final_call/sounds/voice_call.m4a';

  /// File path: assets/games/final_call/sounds/voice_draw.m4a
  String get voiceDraw =>
      'packages/game_final_call/assets/games/final_call/sounds/voice_draw.m4a';

  /// File path: assets/games/final_call/sounds/voice_win_blue.m4a
  String get voiceWinBlue =>
      'packages/game_final_call/assets/games/final_call/sounds/voice_win_blue.m4a';

  /// File path: assets/games/final_call/sounds/voice_win_red.m4a
  String get voiceWinRed =>
      'packages/game_final_call/assets/games/final_call/sounds/voice_win_red.m4a';

  /// File path: assets/games/final_call/sounds/win.mp3
  String get win =>
      'packages/game_final_call/assets/games/final_call/sounds/win.mp3';

  /// List of all assets
  List<String> get values => [
    aGitkeep,
    heartbreak,
    voiceCall,
    voiceDraw,
    voiceWinBlue,
    voiceWinRed,
    win,
  ];
}

class $AssetsGamesFinalCallImagesModalGen {
  const $AssetsGamesFinalCallImagesModalGen();

  /// File path: assets/games/final_call/images/modal/modal_image_door.webp
  AssetGenImage get modalImageDoor => const AssetGenImage(
    'assets/games/final_call/images/modal/modal_image_door.webp',
  );

  /// List of all assets
  List<AssetGenImage> get values => [modalImageDoor];
}

abstract final class Assets {
  static const String package = 'game_final_call';

  static const $AssetsGamesGen games = $AssetsGamesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  static const String package = 'game_final_call';

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

  String get keyName => 'packages/game_final_call/$_assetName';
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
