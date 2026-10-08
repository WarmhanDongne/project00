import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
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
        _error = widget.provider.errorMessage ?? '그룹을 나가지 못했어요. 다시 시도해 주세요.';
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
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: MosiDialogFrame(
                    semanticLabel: '태블릿 연결 끊김',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '태블릿에 다시 연결하는 중',
                          style: MosiFonts.sans(
                            size: 22,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '태블릿의 앱과 인터넷 연결을 확인해 주세요.\n연결되면 이 화면에서 자동으로 이어집니다.',
                          style: MosiFonts.sans(size: 15, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        const Center(child: CircularProgressIndicator()),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: MosiFonts.sans(
                                size: 14,
                                color: MosiColors.red,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        MosiButton(
                          label: '그룹 나가고 홈으로',
                          expand: true,
                          loading: _exiting || widget.provider.isLeaving,
                          onPressed: _exit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
