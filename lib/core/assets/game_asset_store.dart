import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================게임 에셋 단일 해석 지점==============================
/// 게임 이미지·사운드가 실제로 어디서 오는지를 한곳에서 결정합니다.
///
/// 지금은 모든 요청에 **앱 번들 에셋**을 돌려줍니다. 나중에 게임 리소스를
/// 서버에서 내려받는 구조(스토어 심사 없는 게임 추가)로 바꿀 때, 게임 화면
/// 코드는 그대로 두고 이 클래스 뒤에서만 바꿉니다:
///
/// 1. [prepareGame]에서 서버 매니페스트 버전을 확인하고 부족한 파일을 내려받음
/// 2. [imageProviderFor]·[soundSourceFor]가 내려받은 파일을 우선 반환
/// 3. 파일이 없거나 손상됐으면 **번들로 폴백** — 오프라인·다운로드 실패에도
///    출시 시점에 번들된 게임은 항상 동작해야 합니다
///
/// ## 게임 코드 규칙
/// - `lib/games/` 안에서 이미지는 `Assets....game`([GameImage])으로만 씁니다.
///   `Assets....image()`를 직접 호출하면 서버 전환 때 그 화면만 남아서 깨집니다.
/// - 소리는 지금처럼 [SoundService]/[SoundEffects] 경로 문자열을 쓰면 됩니다.
///   소스 해석은 SoundService가 이 클래스에 위임합니다.
class GameAssetStore {
  GameAssetStore();

  /// 전역 인스턴스. 서버 에셋 구현이나 테스트 대역으로 교체할 수 있습니다.
  static GameAssetStore instance = GameAssetStore();

  /// 게임 입장 준비 훅입니다. 각 게임의 에셋 preload 단계에서 호출하세요.
  ///
  /// 지금은 아무것도 하지 않습니다. 서버 에셋 도입 시 여기서 버전 검사와
  /// 다운로드를 수행합니다. 사운드는 보조, 이미지는 번들 폴백이 있으므로
  /// 호출부는 실패를 삼키고 게임 진입을 막지 않아야 합니다.
  Future<void> prepareGame(String gameId) async {}

  /// [GameImage]가 실제 이미지를 그릴 때 사용하는 provider입니다.
  ImageProvider imageProviderFor(AssetGenImage bundled) => bundled.provider();

  /// 사운드 경로(`assets/...`)를 재생 소스로 바꿉니다.
  Source soundSourceFor(String assetPath) =>
      AssetSource(stripAssetPrefix(assetPath));

  /// 사전 준비(AudioCache) 대상 번들 경로입니다.
  ///
  /// 서버에서 내려받은 파일은 이미 기기에 있어 캐시 준비가 필요 없으므로,
  /// 서버 구현에서는 null을 돌려줍니다.
  String? cacheableAssetPath(String assetPath) => stripAssetPrefix(assetPath);

  /// audioplayers의 AssetSource는 `assets/` 접두사를 뺀 경로를 받습니다.
  static String stripAssetPrefix(String path) {
    const assetPrefix = 'assets/';
    if (path.startsWith(assetPrefix)) {
      return path.substring(assetPrefix.length);
    }
    return path;
  }
}
