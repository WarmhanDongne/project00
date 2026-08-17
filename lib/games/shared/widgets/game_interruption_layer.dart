import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

/// 연결 끊김·퇴장 시 모든 게임이 공유하는 전체 화면 중단 및 투표 레이어입니다.
///
/// 문구 전용 [GameAnnouncementLayer]와 달리 이 레이어는 게임 조작을 멈추고
/// 투표 버튼만 입력받습니다.
class GameInterruptionLayer extends StatefulWidget {
  const GameInterruptionLayer({
    super.key,
    required this.interruption,
    required this.currentUid,
    this.onVote,
    this.onExpired,
    this.isSubmitting = false,
    this.scrimColor = const Color(0xE8000000),
  });

  final GameInterruption? interruption;
  final String currentUid;
  final Future<void> Function()? onVote;
  final Future<void> Function()? onExpired;
  final bool isSubmitting;
  final Color scrimColor;

  @override
  State<GameInterruptionLayer> createState() => _GameInterruptionLayerState();
}

class _GameInterruptionLayerState extends State<GameInterruptionLayer> {
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _expiredInterruptionId;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(GameInterruptionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interruption?.id != widget.interruption?.id) {
      _expiredInterruptionId = null;
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    final interruption = widget.interruption;
    if (interruption == null) {
      _remainingSeconds = 0;
      return;
    }
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final interruption = widget.interruption;
    if (interruption == null || !mounted) return;
    final milliseconds = ServerClock.remainingUntil(
      interruption.deadlineAt,
    ).inMilliseconds;
    final seconds = (milliseconds / 1000).ceil();
    if (_remainingSeconds != seconds) {
      setState(() => _remainingSeconds = seconds);
    }
    if (seconds == 0 &&
        _expiredInterruptionId != interruption.id &&
        widget.onExpired != null) {
      _expiredInterruptionId = interruption.id;
      unawaited(widget.onExpired!());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interruption = widget.interruption;
    // 이 레이어는 Stack의 Positioned 자식이라는 전제로 쓰입니다. 중단이 없을 때
    // 맨 SizedBox를 돌려주면 Stack의 유일한 non-positioned 자식이 되어, 느슨한
    // 제약(StackFit.loose)에서는 Stack 전체가 0×0으로 줄어듭니다. 그러면 배경과
    // 게임 레이어가 통째로 그려지지 않아 화면이 검게 보입니다.
    if (interruption == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final canVote = interruption.canVote(widget.currentUid);
    final hasVoted = interruption.hasVoted(widget.currentUid);
    final isDisconnected =
        interruption.reason == GameInterruptionReason.disconnected;
    final title = isDisconnected
        ? '${interruption.playerNickname}님의 연결이 끊어졌습니다'
        : '${interruption.playerNickname}님이 게임에서 나갔습니다';
    final description = interruption.canContinue
        ? '${interruption.playerNickname}님을 제외하고 게임을 계속할까요?'
        : '남은 인원이 부족해 게임을 계속할 수 없습니다.';

    return Positioned.fill(
      child: Material(
        color: widget.scrimColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerAvatar(
                      imageUrl: interruption.playerProfileImageUrl,
                      nickname: interruption.playerNickname,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE5E5E5),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '$_remainingSeconds초',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (interruption.canContinue) ...[
                      const SizedBox(height: 8),
                      Text(
                        '동의 ${interruption.voteCount} / ${interruption.requiredVotes}',
                        style: const TextStyle(
                          color: Color(0xFFCECECE),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (canVote)
                        FilledButton(
                          onPressed: hasVoted || widget.isSubmitting
                              ? null
                              : () => unawaited(widget.onVote?.call()),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: const Color(0xFFAAAAAA),
                            disabledForegroundColor: const Color(0xFF444444),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            hasVoted ? '동의 완료' : '제외하고 계속하기',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        const Text(
                          '다른 플레이어의 투표를 기다리고 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFCECECE)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.imageUrl, required this.nickname});

  final String imageUrl;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFF303030),
      child: Center(
        child: Text(
          nickname.isEmpty ? '?' : nickname.characters.first,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: imageUrl.trim().isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
