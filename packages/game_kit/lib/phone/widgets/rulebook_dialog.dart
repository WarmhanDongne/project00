// [rulebook_dialog.dart] 는 휴대폰 게임의 공통 룰북 다이얼로그를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';

// ============================================================

/// 태블릿 룰북처럼 항목을 골라 읽는 휴대폰 규칙 화면입니다.
///
/// 왼쪽에는 [markdown]의 `# 제목`을 세로로 쌓고, 오른쪽에는 고른 항목의
/// 본문을 보여 줍니다. 판 바깥을 누르거나 닫기 버튼을 누르면 닫힙니다.
class PhoneGameRulebookDialog extends StatefulWidget {
  const PhoneGameRulebookDialog({
    super.key,
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;

  @override
  State<PhoneGameRulebookDialog> createState() =>
      _PhoneGameRulebookDialogState();
}

class _RulePage {
  const _RulePage(this.title, this.body);

  final String title;
  final String body;
}

/// 맨 윗단계 제목(`# `)마다 항목을 나눕니다. 태블릿 룰북과 같은 기준입니다.
List<_RulePage> _splitPages(String markdown) {
  final pages = <_RulePage>[];
  String? title;
  final body = StringBuffer();
  void flush() {
    final text = body.toString().trim();
    if (title != null || text.isNotEmpty) {
      pages.add(_RulePage((title ?? '규칙').localized, text));
    }
    body.clear();
  }

  for (final line in markdown.trim().split('\n')) {
    if (line.startsWith('# ')) {
      flush();
      title = line.substring(2).trim();
    } else {
      body.writeln(line);
    }
  }
  flush();
  return pages.isEmpty ? [_RulePage('규칙'.localized, '')] : pages;
}

class _PhoneGameRulebookDialogState extends State<PhoneGameRulebookDialog> {
  late List<_RulePage> _pages = _splitPages(widget.markdown);
  int _page = 0;

  @override
  void didUpdateWidget(covariant PhoneGameRulebookDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _pages = _splitPages(widget.markdown);
      _page = _page.clamp(0, _pages.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = MosiGameModalTheme.fromName(widget.title);
    final landscape = size.width > size.height;
    final page = _pages[_page];

    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: landscape ? 720 : 440,
          maxHeight: landscape ? size.height * 0.9 : size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MosiColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MosiColors.ink, width: 3),
            boxShadow: [
              BoxShadow(color: theme.accent, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: landscape ? 176 : 112, child: _buildIndex(theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildPage(context, theme, page)),
            ],
          ),
        ),
      ),
    );

    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          // 판 안쪽을 눌렀을 때는 닫히지 않게 막습니다.
          child: GestureDetector(onTap: () {}, child: dialog),
        ),
      ),
    );
  }

  /// 왼쪽: 제목과 세로로 쌓은 항목입니다.
  Widget _buildIndex(MosiGameModalTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '게임 규칙'.localized,
            maxLines: 1,
            style: MosiFonts.sans(
              size: 21,
              weight: FontWeight.w700,
              color: MosiColors.navy,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: theme.deep,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.title,
              maxLines: 1,
              style: MosiFonts.sans(
                size: 12,
                weight: FontWeight.w700,
                color: MosiColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _pages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final selected = index == _page;
              return Semantics(
                button: true,
                selected: selected,
                label: _pages[index].title,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _page = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? theme.deep : MosiColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MosiColors.ink, width: 2),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: MosiFonts.grotesk(
                            size: 12,
                            color: selected ? theme.accent : theme.deep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pages[index].title,
                            style: MosiFonts.sans(
                              size: 13,
                              weight: FontWeight.w700,
                              color: selected
                                  ? MosiColors.white
                                  : MosiColors.navy,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 오른쪽: 고른 항목의 본문입니다.
  Widget _buildPage(
    BuildContext context,
    MosiGameModalTheme theme,
    _RulePage page,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
      decoration: BoxDecoration(
        color: MosiColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MosiColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  page.title,
                  style: MosiFonts.sans(
                    size: 20,
                    weight: FontWeight.w700,
                    color: MosiColors.navy,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MosiSquareCloseButton(
                size: 36,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              // 항목을 바꾸면 처음부터 읽도록 스크롤을 새로 만듭니다.
              key: ValueKey(_page),
              padding: const EdgeInsets.only(right: 6, bottom: 12),
              child: MarkdownBody(
                data: page.body,
                styleSheet: _ruleStyleSheet(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

MarkdownStyleSheet _ruleStyleSheet(MosiGameModalTheme theme) {
  final body = MosiFonts.sans(size: 14, color: MosiColors.navy, height: 1.55);
  return MarkdownStyleSheet(
    p: body,
    strong: body.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: const Color(0x59F2C14E),
    ),
    h2: MosiFonts.sans(
      size: 16,
      weight: FontWeight.w700,
      color: MosiColors.navy,
    ),
    h2Padding: const EdgeInsets.only(top: 6),
    h3: MosiFonts.sans(
      size: 15,
      weight: FontWeight.w700,
      color: MosiColors.navy,
    ),
    listBullet: MosiFonts.grotesk(size: 13, color: theme.deep),
    blockSpacing: 8,
  );
}
