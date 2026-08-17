import 'dart:async';
import 'package:project00/core/time/server_clock.dart';

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/final_call_copy.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

class FinalCallCardChangeDialog extends StatefulWidget {
  const FinalCallCardChangeDialog({
    super.key,
    required this.discardCard,
    required this.canSelectDeck,
    this.deadlineAt,
  });

  final FinalCallCard discardCard;
  final bool canSelectDeck;

  /// 턴 마감 시각(밀리초)입니다. 이 시각이 지나면 선택하지 않아도 창을 닫습니다.
  final int? deadlineAt;

  @override
  State<FinalCallCardChangeDialog> createState() =>
      _FinalCallCardChangeDialogState();
}

class _FinalCallCardChangeDialogState extends State<FinalCallCardChangeDialog> {
  String? source;
  Timer? _deadlineTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoClose();
  }

  /// 턴 타이머가 끝나면 카드 교체 창을 스스로 닫습니다. 창이 남아 있으면
  /// 시간이 지난 뒤에도 화면을 가려 다음 진행이 보이지 않습니다.
  void _scheduleAutoClose() {
    final deadline = widget.deadlineAt;
    if (deadline == null) return;
    final remaining = ServerClock.remainingUntil(deadline).inMilliseconds;
    _deadlineTimer = Timer(
      Duration(milliseconds: remaining.clamp(0, 60000)),
      () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 900;

    final titleWidth = compact ? 68.0 : 82.0;
    final titleFontSize = compact ? 20.0 : 24.0;

    final cardWidth = compact ? 76.0 : 92.0;

    final confirmWidth = compact ? 72.0 : 90.0;
    final confirmHeight = compact ? 84.0 : 98.0;
    final confirmFontSize = compact ? 18.0 : 22.0;

    final gap1 = compact ? 10.0 : 18.0;
    final gap2 = compact ? 12.0 : 20.0;
    final gap3 = compact ? 14.0 : 24.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 130, vertical: 30),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 13),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.games.finalCall.images.background.phoneBackground
                .provider(),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: titleWidth,
              child: Text(
                FinalCallCopy.cardChange,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const VerticalDivider(color: Colors.black26, thickness: 1),
            SizedBox(width: gap1),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModalCard(
                    selected: source == 'deck',
                    enabled: widget.canSelectDeck,
                    onTap: () => setState(() => source = 'deck'),
                    child: FinalCallCardView(faceDown: true, width: cardWidth),
                  ),
                  SizedBox(width: gap2),
                  _ModalCard(
                    selected: source == 'discard',
                    enabled: true,
                    onTap: () => setState(() => source = 'discard'),
                    child: FinalCallCardView(
                      card: widget.discardCard,
                      width: cardWidth,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: gap3),
            GestureDetector(
              onTap: source == null
                  ? null
                  : () => Navigator.pop(context, source),
              child: AnimatedOpacity(
                opacity: source == null ? 0.35 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: confirmWidth,
                  height: confirmHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    FinalCallCopy.confirm,
                    style: TextStyle(
                      fontSize: confirmFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalCard extends StatelessWidget {
  const _ModalCard({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? const Color(0xFFE3D400) : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}
