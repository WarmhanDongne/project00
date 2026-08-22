import 'package:flutter/widgets.dart';

//=======================게임 화면 확실히 닫기==============================
/// 게임 라우트를 닫습니다. 그 위에 다이얼로그가 쌓여 있어도 함께 정리합니다.
///
/// `Navigator.maybePop()`은 **최상단 라우트 하나만** 닫습니다. 그래서 서버가
/// 게임을 비정상 종료(인원 부족·수동 종료)한 순간 설정·룰북·카드 교체 같은
/// 다이얼로그가 열려 있으면 그 다이얼로그만 닫히고 게임 화면은 남습니다.
/// 호출부가 '한 번만 나간다'는 플래그로 잠겨 있으면 다시 시도하지도 않아
/// 사용자가 끝난 게임 화면에 갇힙니다.
///
/// [context]는 **게임 라우트에 속한** context여야 합니다(다이얼로그 내부의
/// context를 넘기면 그 다이얼로그를 게임 화면으로 착각합니다).
void exitGameRoute(BuildContext context) {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  if (route == null) {
    // 라우트를 특정할 수 없으면 최소한 기존 동작은 유지합니다.
    navigator.maybePop();
    return;
  }
  // 게임 라우트 위에 쌓인 것(다이얼로그 등)을 모두 걷어냅니다.
  navigator.popUntil((candidate) => candidate == route);
  // 그런 다음 게임 라우트 자체를 닫습니다.
  if (route.isCurrent) navigator.pop();
}
