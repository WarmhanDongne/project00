import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_helper.dart';

/// CALL 선언 위치에서 짧게 말풍선을 표시합니다.
class FinalCallTabletCallAnimation extends StatefulWidget {
  const FinalCallTabletCallAnimation({
    super.key,
    required this.controller,
    required this.playerCount,
  });
  final PhoneGameController controller;
  final int playerCount;

  @override
  State<FinalCallTabletCallAnimation> createState() =>
      _FinalCallTabletCallAnimationState();
}

class _FinalCallTabletCallAnimationState
    extends State<FinalCallTabletCallAnimation> {
  String? visibleUid;
  String? observedUid;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant FinalCallTabletCallAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final uid = widget.controller.callerUid;
    if (uid == null || uid == observedUid || !mounted) return;
    observedUid = uid;
    timer?.cancel();
    setState(() => visibleUid = uid);
    timer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => visibleUid = null);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = visibleUid;
    final player = widget.controller.players[uid];
    if (uid == null || player == null) return const SizedBox.shrink();
    return Align(
      alignment: finalCallSeatAlignment(player.seatIndex, widget.playerCount),
      child: Padding(
        padding: const EdgeInsets.all(110),
        child: Transform.rotate(
          angle: finalCallSeatRotation(player.seatIndex, widget.playerCount),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8),
              ],
            ),
            child: const Text(
              'CALL',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
