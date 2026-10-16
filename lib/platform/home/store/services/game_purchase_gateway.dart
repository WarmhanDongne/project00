import 'package:project00/platform/home/gamelist/models/game_info.dart';

/// 스토어 결제 구현이 서버 소유권을 바꿨는지 나타냅니다.
enum GamePurchaseResult {
  /// 실제 결제 SDK와 서버 검증이 아직 연결되지 않았습니다.
  notConfigured,

  /// 서버 검증 뒤 소유권이 바뀌었으므로 카탈로그를 다시 읽어야 합니다.
  entitlementsChanged,
}

/// 앱스토어 결제와 구매 복원을 상점 UI에서 분리하는 경계입니다.
///
/// 실제 구현은 플랫폼 거래를 서버에서 검증한 뒤에만
/// [GamePurchaseResult.entitlementsChanged]를 반환해야 합니다. UI는 영수증이나
/// 구매 토큰을 해석하거나 소유권을 직접 쓰지 않습니다.
abstract interface class GamePurchaseGateway {
  const GamePurchaseGateway();

  bool get isConfigured;

  Future<GamePurchaseResult> purchase(GameInfo game);

  Future<GamePurchaseResult> restorePurchases();
}

/// 현재 제품 정책인 '비과금'을 코드로 고정하는 기본 구현입니다.
///
/// 상품 ID가 Firestore에 있더라도 이 게이트웨이를 교체하기 전에는 결제를 열거나
/// 소유권을 변경하지 않습니다.
final class DisabledGamePurchaseGateway implements GamePurchaseGateway {
  const DisabledGamePurchaseGateway();

  @override
  bool get isConfigured => false;

  @override
  Future<GamePurchaseResult> purchase(GameInfo game) async =>
      GamePurchaseResult.notConfigured;

  @override
  Future<GamePurchaseResult> restorePurchases() async =>
      GamePurchaseResult.notConfigured;
}
