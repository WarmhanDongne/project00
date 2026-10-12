import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/widgets/game_route_exit.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 태블릿 진행 기기가 잠시 사라졌을 때 현재 게임 화면과 상태를 보존한 채
/// 참가자 입력만 차단합니다.
class ControllerReconnectGuard extends StatefulWidget {
  const ControllerReconnectGuard({
    super.key,
    required this.provider,
    required this.child,
    required this.onExit,
    this.exitDelay = const Duration(seconds: 10),
  });

  final RoomProvider provider;
  final Widget child;
  final VoidCallback onExit;

  /// 이 시간이 지나도 연결되지 않으면 나가기 버튼을 보여 줍니다(확정 2026-08).
  /// 일시적인 끊김에 바로 나가 버리지 않도록 잠깐 기다리게 합니다.
  final Duration exitDelay;

  @override
  State<ControllerReconnectGuard> createState() =>
      _ControllerReconnectGuardState();
}

class _ControllerReconnectGuardState extends State<ControllerReconnectGuard> {
  bool _observedGameSession = false;
  bool _exitScheduled = false;

  bool get _hasGameSession =>
      (widget.provider.selectedGameId?.isNotEmpty ?? false) ||
      widget.provider.roomStatus == 'playing' ||
      widget.provider.roomStatus == 'finished';

  bool get _isAuthoritativelyBackInWaitingRoom =>
      _observedGameSession &&
      widget.provider.roomCode != null &&
      widget.provider.roomStatus == 'waiting' &&
      !(widget.provider.selectedGameId?.isNotEmpty ?? false);

  void _scheduleFinishedGameExit(BuildContext gameContext) {
    if (_exitScheduled || !_isAuthoritativelyBackInWaitingRoom) return;
    _exitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !gameContext.mounted) return;
      if (!_isAuthoritativelyBackInWaitingRoom) {
        _exitScheduled = false;
        return;
      }
      exitGameRoute(gameContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      child: widget.child,
      builder: (context, child) {
        if (_hasGameSession) _observedGameSession = true;
        _scheduleFinishedGameExit(context);
        final reconnecting =
            widget.provider.isServerConnected &&
            widget.provider.controllerPresenceState ==
                ControllerPresenceState.reconnecting;
        return Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (reconnecting)
              Positioned.fill(
                child: _TabletLostSheet(
                  characterId: widget.provider.currentCharacterId,
                  exitDelay: widget.exitDelay,
                  onExit: widget.onExit,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 시안 '게임 중 태블릿 연결 끊김'입니다.
class _TabletLostSheet extends StatefulWidget {
  const _TabletLostSheet({
    required this.characterId,
    required this.exitDelay,
    required this.onExit,
  });

  final String? characterId;
  final Duration exitDelay;
  final VoidCallback onExit;

  @override
  State<_TabletLostSheet> createState() => _TabletLostSheetState();
}

class _TabletLostSheetState extends State<_TabletLostSheet> {
  Timer? _timer;
  bool _showsExit = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.exitDelay, () {
      if (mounted) setState(() => _showsExit = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MosiConnectionLayout(
      semanticLabel: '태블릿 연결 끊김'.localized,
      background: MosiColors.violet,
      scene: MosiTabletLostScene(characterId: widget.characterId),
      tag: GameLocale.select(
        ko: '게임 중 · 태블릿',
        en: 'In game · Tablet',
        zhHans: '游戏中 · 平板',
        zhHant: '遊戲中 · 平板',
      ),
      tagColor: mosiConnectionLavender,
      title: '태블릿에 다시 연결하는 중'.localized,
      body: GameLocale.select(
        ko: '태블릿 연결이 잠깐 끊겼어요.\n기다리면 이 화면에서 자동으로 이어져요.',
        en: 'The tablet disconnected briefly.\nThis screen will resume automatically.',
        zhHans: '平板暂时断开连接。\n请稍候，此画面会自动恢复。',
        zhHant: '平板暫時中斷連線。\n請稍候，此畫面會自動恢復。',
      ),
      status: MosiConnectionStatus(
        text: GameLocale.select(
          ko: '내 자리와 손패는 그대로예요',
          en: 'Your seat and hand are safe',
          zhHans: '座位和手牌都会保留',
          zhHant: '座位和手牌都會保留',
        ),
      ),
      actions: [
        MosiConnectionButton(
          label: '게임과 그룹 나가기'.localized,
          onPressed: widget.onExit,
        ),
      ],
      footnote: _showsExit
          ? GameLocale.select(
              ko: '나가면 이번 게임에서 빠지게 돼요',
              en: 'Leaving removes you from this game',
              zhHans: '离开后将退出本局游戏',
              zhHant: '離開後將退出本局遊戲',
            )
          : null,
    );
  }
}
