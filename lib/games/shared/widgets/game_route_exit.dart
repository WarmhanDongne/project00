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
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  // pop 직후 애니메이션 중에도 context는 mounted입니다. 이미 비활성인
  // route를 popUntil로 찾으면 대기실·홈까지 모두 닫혀 검정 화면이 됩니다.
  if (route == null || !route.isActive) return;
  // 게임 라우트 위에 쌓인 것(다이얼로그 등)을 모두 걷어냅니다.
  navigator.popUntil((candidate) => candidate == route);
  // 그런 다음 게임 라우트 자체를 닫습니다.
  if (route.isCurrent) navigator.pop();
}
