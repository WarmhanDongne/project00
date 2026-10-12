import 'package:flutter/material.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_kit/localization/game_locale.dart';

/// 벳·레이즈 금액을 고르는 하단 시트입니다.
///
/// 금액은 서버 계약과 같이 이번 스트리트의 목표 누적 투입액(target)입니다.
/// 최대값을 고르면 서버의 `allIn` 행동으로 보냅니다.
class HoldemRaiseSheet extends StatefulWidget {
  const HoldemRaiseSheet({
    super.key,
    required this.legal,
    required this.stack,
    required this.streetContribution,
    required this.potTotal,
    required this.currentBet,
    required this.step,
    required this.enabled,
    required this.onClose,
    required this.onConfirm,
  });
  final HoldemLegalActionsModel legal;
  final int stack;
  final int streetContribution;
  final int potTotal;
  final int currentBet;
  final int step;
  final bool enabled;
  final VoidCallback onClose;
  final void Function(String action, int? amount) onConfirm;

  @override
  State<HoldemRaiseSheet> createState() => _HoldemRaiseSheetState();
}

class _HoldemRaiseSheetState extends State<HoldemRaiseSheet> {
  late int _target = _min;

  int get _max => widget.legal.maximumTarget;
  int get _min => widget.legal.minimumTarget ?? _max;
  bool get _canChoose => widget.legal.minimumTarget != null && _max > _min;

  @override
  void didUpdateWidget(covariant HoldemRaiseSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.legal != widget.legal) _target = _clamp(_target);
  }

  int _clamp(int value) => value.clamp(_min, _max);

  @override
  Widget build(BuildContext context) {
    final target = _clamp(_target);
    final allIn = target >= _max;
    final verb = allIn
        ? 'All-in'
        : widget.legal.bet
        ? 'Bet'
        : 'Raise';
    final left = widget.stack - (target - widget.streetContribution);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      decoration: BoxDecoration(
        color: HoldemColors.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: HoldemColors.line(.16))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 40,
            offset: const Offset(0, -16),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: HoldemColors.line(.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    HoldemCopy.raiseTitle,
                    style: HoldemFonts.text(size: 18, weight: FontWeight.w900),
                  ),
                ),
                HoldemCircleIconButton(
                  icon: Icons.close_rounded,
                  label: HoldemCopy.close,
                  size: 44,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  label: GameLocale.select(
                    ko: '${widget.step} 내리기',
                    en: 'Decrease by ${widget.step}',
                    zhHans: '减少 ${widget.step}',
                    zhHant: '減少 ${widget.step}',
                  ),
                  onPressed: _canChoose && target > _min
                      ? () => setState(
                          () => _target = _clamp(target - widget.step),
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(
                          holdemChips(target),
                          style: HoldemFonts.numbers(size: 84),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        GameLocale.select(
                          ko: '베팅 후 남는 칩 ${holdemChips(left)}',
                          en: 'Chips left ${holdemChips(left)}',
                          zhHans: '下注后剩余 ${holdemChips(left)}',
                          zhHant: '下注後剩餘 ${holdemChips(left)}',
                        ),
                        style: HoldemFonts.text(
                          size: 13,
                          color: HoldemColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  label: GameLocale.select(
                    ko: '${widget.step} 올리기',
                    en: 'Increase by ${widget.step}',
                    zhHans: '增加 ${widget.step}',
                    zhHant: '增加 ${widget.step}',
                  ),
                  onPressed: _canChoose && target < _max
                      ? () => setState(
                          () => _target = _clamp(target + widget.step),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                activeTrackColor: HoldemColors.ivory,
                inactiveTrackColor: HoldemColors.line(.18),
                thumbColor: HoldemColors.ivory,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 17,
                  elevation: 4,
                  pressedElevation: 6,
                ),
                overlayColor: HoldemColors.line(.16),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: target.toDouble(),
                min: _min.toDouble(),
                max: _canChoose ? _max.toDouble() : _min.toDouble() + 1,
                semanticFormatterCallback: (value) => GameLocale.select(
                  ko: '레이즈 금액 ${holdemChips(value.round())}',
                  en: 'Raise to ${holdemChips(value.round())}',
                  zhHans: '加注至 ${holdemChips(value.round())}',
                  zhHant: '加注至 ${holdemChips(value.round())}',
                ),
                onChanged: _canChoose
                    ? (value) => setState(() => _target = _snap(value))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    GameLocale.select(
                      ko: '최소 ${holdemChips(_min)}',
                      en: 'Min ${holdemChips(_min)}',
                      zhHans: '最低 ${holdemChips(_min)}',
                      zhHant: '最低 ${holdemChips(_min)}',
                    ),
                    style: HoldemFonts.text(
                      size: 12,
                      color: HoldemColors.muted,
                    ),
                  ),
                  Text(
                    '${HoldemCopy.action('allIn')} ${holdemChips(_max)}',
                    style: HoldemFonts.text(
                      size: 12,
                      color: HoldemColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            HoldemPuckButton(
              label: verb,
              amount: holdemChips(target),
              size: 128,
              onPressed: widget.enabled
                  ? () => widget.onConfirm(
                      allIn ? 'allIn' : (widget.legal.bet ? 'bet' : 'raise'),
                      allIn ? null : target,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 슬라이더 값을 빅 블라인드 단위로 맞추되 최소·최대값은 그대로 허용합니다.
  int _snap(double value) {
    final raw = value.round();
    if (raw >= _max) return _max;
    if (raw <= _min) return _min;
    final step = widget.step <= 0 ? 1 : widget.step;
    final snapped = _min + ((raw - _min) / step).round() * step;
    return _clamp(snapped);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    enabled: onPressed != null,
    excludeSemantics: true,
    child: Opacity(
      opacity: onPressed == null ? .38 : 1,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: HoldemColors.line(.28))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, color: HoldemColors.ivory, size: 22),
          ),
        ),
      ),
    ),
  );
}
