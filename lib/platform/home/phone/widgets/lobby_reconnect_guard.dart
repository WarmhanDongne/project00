import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 대기실 본문을 보존하며 태블릿 연결 복구를 기다립니다.
/// 휴대폰 자체 단절은 바깥 CriticalNetworkGuard가 담당합니다.
class LobbyReconnectGuard extends StatefulWidget {
  const LobbyReconnectGuard({
    super.key,
    required this.provider,
    required this.onExit,
    required this.child,
  });

  final RoomProvider provider;
  final Future<bool> Function() onExit;
  final Widget child;

  @override
  State<LobbyReconnectGuard> createState() => _LobbyReconnectGuardState();
}

class _LobbyReconnectGuardState extends State<LobbyReconnectGuard> {
  bool _exiting = false;
  String? _error;

  Future<void> _exit() async {
    if (_exiting || widget.provider.isLeaving) return;
    setState(() {
      _exiting = true;
      _error = null;
    });
    bool left;
    try {
      left = await widget.onExit();
    } catch (_) {
      left = false;
    }
    if (!mounted) return;
    setState(() {
      _exiting = false;
      if (!left) {
        _error =
            widget.provider.errorMessage ??
            GameLocale.select(
              ko: '그룹을 나가지 못했어요. 다시 시도해 주세요.',
              en: 'Could not leave the room. Try again.',
              zhHans: '无法离开房间，请重试。',
              zhHant: '無法離開房間，請重試。',
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      child: widget.child,
      builder: (context, child) {
        final reconnecting =
            widget.provider.isServerConnected &&
            widget.provider.controllerPresenceState ==
                ControllerPresenceState.reconnecting &&
            (ModalRoute.of(context)?.isCurrent ?? true);
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(excluding: reconnecting, child: child!),
            if (reconnecting) ...[
              const ModalBarrier(
                key: Key('lobby-reconnect-barrier'),
                dismissible: false,
                color: MosiColors.scrim,
              ),
              Positioned.fill(
                child: MosiConnectionLayout(
                  semanticLabel: '태블릿 연결 끊김'.localized,
                  background: mosiConnectionLavender,
                  scene: MosiLobbyLostScene(
                    characterIds: [
                      for (final player in widget.provider.players)
                        if (player.isActive) player.characterId,
                    ],
                  ),
                  tag: GameLocale.select(
                    ko: '대기실 · 태블릿',
                    en: 'Lobby · Tablet',
                    zhHans: '大厅 · 平板',
                    zhHant: '大廳 · 平板',
                  ),
                  tagColor: mosiConnectionLavender,
                  title: '태블릿에 다시 연결하는 중'.localized,
                  body: GameLocale.select(
                    ko: '태블릿의 앱과 인터넷 연결을 확인해 주세요.\n연결되면 이 화면에서 자동으로 이어져요.',
                    en: 'Check the app and internet connection on the tablet.\nThis screen resumes automatically when it reconnects.',
                    zhHans: '请检查平板应用与网络连接。\n重新连接后此画面会自动恢复。',
                    zhHant: '請檢查平板 App 與網路連線。\n重新連線後此畫面會自動恢復。',
                  ),
                  status: MosiConnectionStatus(
                    text: GameLocale.select(
                      ko: '그룹은 그대로 유지돼요',
                      en: 'The room is being kept',
                      zhHans: '房间会保持不变',
                      zhHant: '房間會保持不變',
                    ),
                  ),
                  extra: _error == null
                      ? null
                      : Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: MosiFonts.sans(
                              size: 14,
                              weight: FontWeight.w700,
                              color: MosiColors.red,
                            ),
                          ),
                        ),
                  actions: [
                    MosiConnectionButton(
                      label: '그룹 나가고 홈으로'.localized,
                      loading: _exiting || widget.provider.isLeaving,
                      onPressed: _exit,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
