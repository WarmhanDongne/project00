import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';

export 'package:game_kit/core/assets/game_image.dart';

extension FinalCallImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

extension FinalCallImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
