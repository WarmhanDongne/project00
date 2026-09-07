import 'package:game_mafia/gen/assets.gen.dart';
import 'package:mosigame_core/core/assets/game_image.dart';

export 'package:mosigame_core/core/assets/game_image.dart';

extension MafiaImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

extension MafiaImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
