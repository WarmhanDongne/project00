// [rule_dialog.dart] 는 휴대폰 게임의 공통 규칙 다이얼로그를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';

// ============================================================

/// 휴대폰 상단 룰북 아이콘에서 여는 공용 규칙 화면입니다.
///
/// 시안: 흰 판 + '게임 규칙' 제목과 게임 이름 꼬리표, 문단마다 번호 칸,
/// 아래 '알겠어요'. 색 인자는 예전 호출과의 호환을 위해 받기만 합니다.
class PhoneGameRuleDialog extends StatelessWidget {
  const PhoneGameRuleDialog({
    super.key,
    required this.title,
    required this.rules,
    required this.surfaceColor,
    required this.foregroundColor,
    this.showSurface = true,
    this.dismissOnAnyTap = false,
  });

  final String title;
  final String rules;
  final Color surfaceColor;
  final Color foregroundColor;
  final bool showSurface;
  final bool dismissOnAnyTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = MosiGameModalTheme.fromName(title);
    final paragraphs = rules
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);

    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width > size.height ? 640 : 420,
          maxHeight: size.height * 0.86,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: MosiColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MosiColors.ink, width: 3),
            boxShadow: [
              BoxShadow(color: theme.accent, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '게임 규칙',
                    style: MosiFonts.sans(
                      size: 24,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.deep,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: MosiFonts.sans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  MosiSquareCloseButton(
                    size: 44,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: paragraphs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: index.isEven ? MosiColors.cream : MosiColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MosiColors.ink, width: 2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.deep,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: MosiFonts.grotesk(
                              size: 13,
                              color: MosiColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            paragraphs[index],
                            style: MosiFonts.sans(
                              size: 14,
                              color: const Color(0xFF3B3866),
                              height: 1.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MosiButton(
                label: '알겠어요',
                background: theme.accent,
                foreground: theme.accentFg,
                shadowOffset: 0,
                height: 52,
                radius: 12,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (!dismissOnAnyTap) return dialog;

    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(child: dialog),
      ),
    );
  }
}
