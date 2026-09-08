import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';

export 'package:game_kit/core/assets/game_image.dart';

extension LiarsPokerImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

extension LiarsPokerImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
