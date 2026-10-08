import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

/// 앱을 다시 켰을 때 기존 방·게임으로 돌아갈지 묻습니다.
///
/// **왜 필요한가.** 지금까지는 복원에 성공하면 **묻지 않고** 곧바로 대기 화면과
/// 게임 화면을 열었습니다(`phone_home.dart`). 사용자가 게임을 그만두려고 앱을
/// 껐어도 다시 켜면 그 방으로 끌려 들어갑니다. 특히 진행 중인 방은 15분 동안
/// 유지되므로(C-03) 그 사이 매번 끌려 들어갑니다.
///
/// **서버에 쓰기 전에 묻습니다.** `restorePlayerRoom()`은 참가자 노드를 되살리고
/// heartbeat를 시작합니다. 묻기도 전에 부르면 사용자가 거절해도 이미 방에 들어가
/// 있게 됩니다. 그래서 `detectRestorableSession()`으로 판정만 먼저 합니다.
class SessionReturnPrompt extends StatelessWidget {
  const SessionReturnPrompt({
    super.key,
    required this.session,
    required this.onReturn,
    required this.onDecline,
    this.isBusy = false,
  });

  /// 무엇으로 돌아갈 수 있는지입니다. [RestorableSession.none]은 이 화면을
  /// 띄우는 쪽에서 이미 걸러야 합니다.
  final RestorableSession session;

  final VoidCallback onReturn;
  final VoidCallback onDecline;

  /// 복귀 요청이 서버로 가 있는 중입니다.
  final bool isBusy;

  bool get _isGame => session == RestorableSession.activeGame;

  @override
  Widget build(BuildContext context) {
    // 시안 '앱을 다시 켰을 때': 둥근 테이블과 비워 둔 내 자리를 보여 줍니다.
    return Scaffold(
      body: MosiConnectionLayout(
        semanticLabel: _isGame ? '진행 중인 게임' : '참여 중인 그룹',
        background: MosiColors.sun,
        scene: const MosiReturnTableScene(),
        tag: _isGame ? '게임 진행 중' : '그룹 참여 중',
        tagColor: MosiColors.lime,
        title: _isGame ? '진행 중인 게임이 있어요' : '참여 중인 그룹이 있어요',
        body: _isGame ? '이어서 하시겠어요?\n자리와 손패는 그대로예요.' : '그룹으로 돌아가시겠어요?',
        actionFlex: const [10, 17],
        actions: [
          MosiConnectionButton(
            key: const ValueKey('session-return-decline'),
            label: '나중에',
            onPressed: isBusy ? null : onDecline,
          ),
          MosiConnectionButton(
            key: const ValueKey('session-return-accept'),
            label: _isGame ? '게임 다시 참여' : '그룹 다시 참여',
            primary: true,
            loading: isBusy,
            onPressed: isBusy ? null : onReturn,
          ),
        ],
      ),
    );
  }
}
