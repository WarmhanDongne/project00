import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/phone/widgets/board_summary.dart';
import 'package:game_holdem/phone/widgets/hand_result_view.dart';
import 'package:game_holdem/phone/widgets/hand_receive_animation.dart';
import 'package:game_holdem/phone/widgets/raise_sheet.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';

const _actionWindow = Duration(seconds: 20);

/// 휴대폰 진행 화면입니다. 내 차례·대기·판 결과를 서버 상태로 나눠 그립니다.
class HoldemPhoneGameScreen extends StatefulWidget {
  const HoldemPhoneGameScreen({
    super.key,
    required this.game,
    required this.uid,
    required this.onAction,
  });
  final HoldemGameState game;
  final String uid;
  final Future<bool> Function(String action, {int? amount}) onAction;

  @override
  State<HoldemPhoneGameScreen> createState() => _HoldemPhoneGameScreenState();
}

class _HoldemPhoneGameScreenState extends State<HoldemPhoneGameScreen>
    with SingleTickerProviderStateMixin {
  (int, String, int?)? _lastVibratedTurn;
  bool _raiseOpen = false;
  bool _handRevealed = false;
  bool _turnExpired = false;
  String? _submittingAction;
  int? _acceptedActionRevision;
  late final AnimationController _controlsEntry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  );

  @override
  void initState() {
    super.initState();
    _controlsEntry.forward();
    _notifyMyTurn();
  }

  @override
  void dispose() {
    _controlsEntry.dispose();
    super.dispose();
  }

  bool _isMyTurn(HoldemGameState game) =>
      game.turnUid == widget.uid && game.legalActions != null;

  void _notifyMyTurn() {
    final game = widget.game;
    if (game.loading ||
        game.status != 'playing' ||
        !const {'preflop', 'flop', 'turn', 'river'}.contains(game.phase) ||
        !_isMyTurn(game) ||
        game.interruption != null ||
        ServerClock.hasPassed(game.turnDeadlineAt)) {
      return;
    }
    final key = (game.handNumber, game.phase, game.turnDeadlineAt);
    if (_lastVibratedTurn == key) return;
    _lastVibratedTurn = key;
    // 공개/개인 snapshot의 도착 순서와 무관하게 준비된 내 턴에 한 번만.
    unawaited(
      HapticFeedback.mediumImpact().catchError((Object error) {
        debugPrint('홀덤 턴 진동을 재생하지 못했습니다: $error');
      }),
    );
  }

  Future<bool> _submitAction(String action, {int? amount}) async {
    if (_submittingAction != null || widget.game.commandInFlight) return false;
    final submittedRevision = widget.game.revision;
    final wasRaiseOpen = _raiseOpen;
    // 금액 확인 즉시 시트를 닫고 누른 퍽을 눌린 상태로 남깁니다.
    // 실제 칩·턴 상태는 서버 공개 상태가 도착할 때만 바뀝니다.
    setState(() {
      _submittingAction = action;
      _raiseOpen = false;
    });
    final accepted = await widget.onAction(action, amount: amount);
    if (!mounted) return accepted;
    setState(() {
      if (accepted &&
          widget.game.revision == submittedRevision &&
          _isMyTurn(widget.game)) {
        // Callable 성공 응답이 RTDB 공개 상태보다 먼저 도착할 수 있습니다.
        // 새 revision을 받을 때까지 버튼을 계속 잠가 같은 턴 행동이 중복으로
        // 전송되지 않게 합니다.
        _acceptedActionRevision = submittedRevision;
      } else {
        _submittingAction = null;
        _acceptedActionRevision = null;
        if (!accepted &&
            wasRaiseOpen &&
            widget.game.revision == submittedRevision &&
            _isMyTurn(widget.game)) {
          _raiseOpen = true;
        }
      }
    });
    return accepted;
  }

  void _expireTurn() {
    if (!mounted || !_isMyTurn(widget.game) || _turnExpired) return;
    setState(() {
      _turnExpired = true;
      _raiseOpen = false;
    });
  }

  bool _actionStateAdvanced(HoldemGameState game) {
    final acceptedRevision = _acceptedActionRevision;
    return acceptedRevision != null &&
        (game.revision != acceptedRevision || !_isMyTurn(game));
  }

  bool _turnIdentityChanged(HoldemGameState oldGame, HoldemGameState game) {
    return oldGame.handNumber != game.handNumber ||
        oldGame.phase != game.phase ||
        oldGame.turnUid != game.turnUid ||
        oldGame.turnDeadlineAt != game.turnDeadlineAt;
  }

  void _clearAcceptedAction() {
    _submittingAction = null;
    _acceptedActionRevision = null;
  }

  void _syncTurnState(HoldemGameState oldGame, HoldemGameState game) {
    if (_turnIdentityChanged(oldGame, game)) {
      _turnExpired = false;
    }
    if (_actionStateAdvanced(game)) {
      _clearAcceptedAction();
    }
  }

  @override
  void didUpdateWidget(covariant HoldemPhoneGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTurnState(oldWidget.game, widget.game);
    _notifyMyTurn();
    if (oldWidget.game.handNumber != widget.game.handNumber) {
      _handRevealed = false;
      _controlsEntry.forward(from: 0);
    }
    final myTurn = _isMyTurn(widget.game);
    if (!myTurn || oldWidget.game.revision != widget.game.revision) {
      _raiseOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = game.players[widget.uid];
    final myTurn = _isMyTurn(game);
    final legal = game.legalActions;
    final content = game.phase == 'handResult'
        ? HoldemHandResultView(
            key: ValueKey('result-${game.handNumber}'),
            game: game,
            uid: widget.uid,
          )
        : Column(
            children: [
              SizedBox(
                height: 62,
                child: ControlEntryAnimation(
                  animation: _controlsEntry,
                  style: ControlEntryStyle.header,
                  begin: 0,
                  end: .38,
                  child: Center(
                    child: myTurn
                        ? _TurnHeadline(
                            game: game,
                            uid: widget.uid,
                            onTimeout: _expireTurn,
                          )
                        : _WaitingHeadline(game: game, uid: widget.uid),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ControlEntryAnimation(
                  animation: _controlsEntry,
                  style: ControlEntryStyle.header,
                  begin: .12,
                  end: .55,
                  child: Center(child: _MyChips(amount: me?.stack ?? 0)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                key: const Key('holdem-phone-hand-area'),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 300,
                    height: 214,
                    child: Center(child: _hand(game, me)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: Center(
                  child: !_handRevealed && game.hand.length == 2
                      ? const _PeekHint()
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                key: const Key('holdem-phone-actions-area'),
                height: 150,
                child: myTurn && legal != null
                    ? ControlEntryAnimation(
                        animation: _controlsEntry,
                        style: ControlEntryStyle.heavyDrop,
                        begin: .45,
                        end: 1,
                        child: _ActionPucks(
                          legal: legal,
                          checkOrCallAction: _checkOrCallAction(game, me),
                          callAmount: _callAmount(game, me),
                          checkOrCallSynchronized: _checkOrCallIsSynchronized(
                            game,
                            me,
                            legal,
                          ),
                          enabled:
                              !_turnExpired &&
                              !game.commandInFlight &&
                              _submittingAction == null,
                          submittingAction: _submittingAction,
                          onFold: () => unawaited(_submitAction('fold')),
                          onCheckOrCall: (action) =>
                              unawaited(_submitAction(action)),
                          onRaise: () => setState(() => _raiseOpen = true),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
              if (game.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: HoldemFonts.text(
                      weight: FontWeight.w700,
                      color: HoldemColors.danger,
                    ),
                  ),
                ),
            ],
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 66, 20, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .985, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                // 스트리트가 바뀌어도 손패 수령 State는 유지합니다. 결과 화면으로
                // 넘어갈 때만 진행 요소를 부드럽게 퇴장시킵니다.
                key: ValueKey(
                  game.phase == 'handResult'
                      ? 'result-${game.handNumber}'
                      : 'playing-${game.handNumber}',
                ),
                child: content,
              ),
            ),
          ),
        ),
        if (_raiseOpen && myTurn && legal != null && me != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _raiseOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: .4)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: HoldemRaiseSheet(
              legal: legal,
              stack: me.stack,
              streetContribution: me.streetContribution,
              potTotal: game.potTotal,
              currentBet: game.currentBet,
              step: game.bigBlind,
              enabled: !game.commandInFlight && _submittingAction == null,
              onClose: () => setState(() => _raiseOpen = false),
              onConfirm: (action, amount) =>
                  unawaited(_submitAction(action, amount: amount)),
            ),
          ),
        ],
      ],
    );
  }

  String _checkOrCallAction(HoldemGameState game, HoldemPlayerModel? me) =>
      _amountToCall(game, me) == 0 ? 'check' : 'call';

  bool _checkOrCallIsSynchronized(
    HoldemGameState game,
    HoldemPlayerModel? me,
    HoldemLegalActionsModel legal,
  ) {
    final amount = _amountToCall(game, me);
    if (amount == 0) return legal.check && legal.toCall == 0;
    return legal.call && legal.toCall == amount;
  }

  int _callAmount(HoldemGameState game, HoldemPlayerModel? me) {
    final amount = _amountToCall(game, me);
    final stack = me?.stack ?? 0;
    return amount > stack ? stack : amount;
  }

  int _amountToCall(HoldemGameState game, HoldemPlayerModel? me) {
    final amount = game.currentBet - (me?.streetContribution ?? 0);
    return amount > 0 ? amount : 0;
  }

  Widget _hand(HoldemGameState game, HoldemPlayerModel? me) {
    if (me == null || me.status == 'eliminated' || game.hand.isEmpty) {
      return const HoldemHoleCards(cards: [], faceDown: true, dimmed: true);
    }
    final folded = me.handStatus == 'folded' || _submittingAction == 'fold';
    if (!_handRevealed && game.hand.length == 2) {
      return HoldemHandReceiveAnimation(
        key: ValueKey('receive-${game.handNumber}'),
        cards: game.hand,
        onCompleted: () {
          if (mounted) setState(() => _handRevealed = true);
        },
      );
    }
    return HoldemHoleCards(cards: game.hand, dimmed: folded);
  }
}

class _TurnHeadline extends StatelessWidget {
  const _TurnHeadline({
    required this.game,
    required this.uid,
    required this.onTimeout,
  });
  final HoldemGameState game;
  final String uid;
  final VoidCallback onTimeout;

  @override
  Widget build(BuildContext context) {
    final last = game.lastAction;
    final actor = last == null || last.uid == uid
        ? null
        : game.players[last.uid];
    final detail = actor == null
        ? HoldemCopy.phase(game.phase)
        : HoldemCopy.actionSentence(actor.nickname, last!.kind, last.amount);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GameTurnCountdownFace(
          expiresAt: game.turnDeadlineAt,
          onTimeout: onTimeout,
          builder: (_, remaining) => HoldemTimerRing(
            seconds: remaining?.inSeconds ?? 0,
            fraction: remaining == null
                ? 0
                : remaining.inMilliseconds / _actionWindow.inMilliseconds,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                HoldemCopy.myTurn,
                style: HoldemFonts.text(size: 20, weight: FontWeight.w900),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingHeadline extends StatelessWidget {
  const _WaitingHeadline({required this.game, required this.uid});
  final HoldemGameState game;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final me = game.players[uid];
    final current = game.players[game.turnUid];
    final title = me?.status == 'eliminated'
        ? HoldemCopy.eliminated
        : game.phase == 'dealing'
        ? HoldemCopy.dealing
        : current == null
        ? HoldemCopy.waiting
        : '${current.nickname} 님이 고민 중';
    final last = game.lastAction;
    final String detail;
    if (me?.status == 'eliminated') {
      detail = HoldemCopy.eliminatedHint;
    } else if (me?.handStatus == 'folded') {
      detail = '${HoldemCopy.folded} · ${HoldemCopy.checkTablet}';
    } else if (last != null && last.uid == uid) {
      final amount = last.amount > 0 && last.kind != 'check'
          ? ' ${holdemChips(last.amount)}'
          : '';
      detail =
          '나는 ${HoldemCopy.action(last.kind)}$amount 완료 · '
          '${HoldemCopy.checkTablet}';
    } else {
      detail = HoldemCopy.checkTablet;
    }
    final thinking = me?.status != 'eliminated' && current != null;
    return Column(
      children: [
        // 긴 닉네임도 자르지 않고 한 줄에 맞춰 줄입니다.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                style: HoldemFonts.text(size: 20, weight: FontWeight.w900),
              ),
              if (thinking) ...[
                const SizedBox(width: 10),
                const _ThinkingDots(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
        ),
      ],
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Opacity(
              opacity: _dotOpacity(_controller.value - index * .17),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: HoldemColors.ivory,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  double _dotOpacity(double phase) {
    final t = phase % 1;
    final wave = t < .5 ? t * 2 : (1 - t) * 2;
    return .25 + wave * .75;
  }
}

class _PeekHint extends StatelessWidget {
  const _PeekHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: HoldemColors.line(.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.visibility_outlined,
          size: 16,
          color: HoldemColors.ivory,
        ),
        const SizedBox(width: 8),
        Text(
          HoldemCopy.peekHint,
          style: HoldemFonts.text(size: 13, weight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ActionPucks extends StatelessWidget {
  const _ActionPucks({
    required this.legal,
    required this.checkOrCallAction,
    required this.callAmount,
    required this.checkOrCallSynchronized,
    required this.enabled,
    required this.submittingAction,
    required this.onFold,
    required this.onCheckOrCall,
    required this.onRaise,
  });
  final HoldemLegalActionsModel legal;
  final String checkOrCallAction;
  final int callAmount;
  final bool checkOrCallSynchronized;
  final bool enabled;
  final String? submittingAction;
  final VoidCallback onFold;
  final ValueChanged<String> onCheckOrCall;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    final canRaise = legal.bet || legal.raise || legal.allIn;
    final canCheck = checkOrCallAction == 'check';
    final raiseLabel = legal.bet
        ? 'Bet'
        : legal.raise
        ? 'Raise'
        : 'All-in';
    // 퍽 세 개(100·112·100)가 좁은 휴대폰 폭보다 넓으면 같은 비율로 줄입니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(1.0, (constraints.maxWidth - 4) / 324);
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              HoldemPuckButton(
                size: 100 * scale,
                label: 'Fold',
                dark: true,
                busy: submittingAction == 'fold',
                semanticLabel: '폴드, 이번 판 포기',
                onPressed: enabled && legal.fold ? onFold : null,
              ),
              HoldemPuckButton(
                label: canCheck ? 'Check' : 'Call',
                amount: canCheck ? null : holdemChips(callAmount),
                size: 112 * scale,
                busy: submittingAction == 'check' || submittingAction == 'call',
                semanticLabel: canCheck ? '체크' : '콜 ${holdemChips(callAmount)}',
                onPressed: enabled && checkOrCallSynchronized
                    ? () => onCheckOrCall(checkOrCallAction)
                    : null,
              ),
              HoldemPuckButton(
                size: 100 * scale,
                label: raiseLabel,
                busy:
                    submittingAction == 'bet' ||
                    submittingAction == 'raise' ||
                    submittingAction == 'allIn',
                semanticLabel: '$raiseLabel 금액 고르기',
                onPressed: enabled && canRaise ? onRaise : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyChips extends StatelessWidget {
  const _MyChips({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '내 칩 ${holdemChips(amount)}',
    excludeSemantics: true,
    // 칩 숫자가 커도 넘치지 않게 줄 전체를 폭에 맞춰 줄입니다.
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HoldemChip(size: 18),
          const SizedBox(width: 8),
          Text(
            '내 칩',
            style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
          ),
          const SizedBox(width: 8),
          Text(holdemChips(amount), style: HoldemFonts.numbers(size: 27)),
        ],
      ),
    ),
  );
}
