import 'package:flutter/material.dart';

/// 휴대폰 상단 룰북 아이콘에서 여는 간단한 공용 규칙 화면입니다.
class PhoneGameRuleDialog extends StatelessWidget {
  const PhoneGameRuleDialog({
    super.key,
    required this.title,
    required this.rules,
    required this.surfaceColor,
    required this.foregroundColor,
  });

  final String title;
  final String rules;
  final Color surfaceColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width > size.height ? 620 : 380,
          maxHeight: size.height * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      rules,
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.86),
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: foregroundColor,
                      foregroundColor: surfaceColor,
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
