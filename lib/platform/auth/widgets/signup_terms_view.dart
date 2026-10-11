// [signup_terms_view.dart] 는 회원가입 첫 단계의 약관 동의 화면을 구성하는 파일이다.
//
// - [Platform] : 회원가입(이메일·Google·Apple 공통)
// - [Screen] : 전체 동의, 필수·선택 항목, 문서 전문 보기
//
// 즉, 가입 전에 약관을 확인하고 동의를 받기 위해 필요한 파일이다.

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';

/// 약관 동의 단계입니다(시안 '회원가입 약관 동의').
///
/// 필수 세 항목(만 14세 이상·이용약관·개인정보 수집·이용)에 모두 동의해야
/// [onAgreed]가 불립니다. 마케팅 소식 받기는 선택입니다.
class SignupTermsView extends StatefulWidget {
  const SignupTermsView({
    super.key,
    required this.onAgreed,
    this.initial = const SignupConsents(),
    this.busy = false,
  });

  final ValueChanged<SignupConsents> onAgreed;
  final SignupConsents initial;
  final bool busy;

  @override
  State<SignupTermsView> createState() => _SignupTermsViewState();
}

enum _TermsItem { age14, terms, privacy, marketing }

class _SignupTermsViewState extends State<SignupTermsView> {
  late SignupConsents _consents = widget.initial;

  bool _isOn(_TermsItem item) => switch (item) {
    _TermsItem.age14 => _consents.age14,
    _TermsItem.terms => _consents.terms,
    _TermsItem.privacy => _consents.privacy,
    _TermsItem.marketing => _consents.marketing,
  };

  void _set(_TermsItem item, bool value) => setState(() {
    _consents = switch (item) {
      _TermsItem.age14 => _consents.copyWith(age14: value),
      _TermsItem.terms => _consents.copyWith(terms: value),
      _TermsItem.privacy => _consents.copyWith(privacy: value),
      _TermsItem.marketing => _consents.copyWith(marketing: value),
    };
  });

  void _toggleAll() {
    final value = !_consents.allAgreed;
    setState(
      () => _consents = SignupConsents(
        age14: value,
        terms: value,
        privacy: value,
        marketing: value,
      ),
    );
  }

  Future<void> _view(_TermsItem item, LegalDocument document) async {
    final agreed = await showLegalDocumentSheet(context, document);
    if (agreed == true && mounted) _set(item, true);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final left = _consents.requiredLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WELCOME',
          style: MosiFonts.grotesk(
            locale: locale,
            size: 13,
            color: MosiColors.violet,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '모시겜을 시작하기 전에\n약관을 확인해 주세요',
          style: MosiFonts.sans(
            locale: locale,
            size: 22,
            weight: FontWeight.w700,
            color: MosiColors.navy,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        _AllAgreeCard(
          checked: _consents.allAgreed,
          onTap: widget.busy ? null : _toggleAll,
        ),
        Container(
          height: 1.5,
          margin: const EdgeInsets.fromLTRB(4, 18, 4, 6),
          color: const Color(0xFFE4E0F2),
        ),
        _TermsRow(
          key: const ValueKey('terms-age14'),
          required: true,
          title: '만 14세 이상이에요',
          sub: '만 14세 미만은 가입할 수 없어요',
          checked: _isOn(_TermsItem.age14),
          onToggle: widget.busy
              ? null
              : () => _set(_TermsItem.age14, !_isOn(_TermsItem.age14)),
        ),
        _TermsRow(
          key: const ValueKey('terms-terms'),
          required: true,
          title: '이용약관 동의',
          sub: '앱 이용 규칙과 금지 행위',
          checked: _isOn(_TermsItem.terms),
          onToggle: widget.busy
              ? null
              : () => _set(_TermsItem.terms, !_isOn(_TermsItem.terms)),
          onView: () => _view(_TermsItem.terms, termsOfService),
        ),
        _TermsRow(
          key: const ValueKey('terms-privacy'),
          required: true,
          title: '개인정보 수집·이용 동의',
          sub: '이메일, 닉네임, 계정 식별자, 프로필 사진(선택)',
          checked: _isOn(_TermsItem.privacy),
          onToggle: widget.busy
              ? null
              : () => _set(_TermsItem.privacy, !_isOn(_TermsItem.privacy)),
          onView: () => _view(_TermsItem.privacy, privacyPolicy),
        ),
        _TermsRow(
          key: const ValueKey('terms-marketing'),
          required: false,
          title: '새 게임·이벤트 소식 받기',
          sub: '원할 때 언제든 끌 수 있어요',
          checked: _isOn(_TermsItem.marketing),
          onToggle: widget.busy
              ? null
              : () => _set(_TermsItem.marketing, !_isOn(_TermsItem.marketing)),
        ),
        const SizedBox(height: 20),
        if (left == 0)
          MosiButton(
            key: const ValueKey('terms-continue'),
            label: '동의하고 계속하기',
            height: 54,
            expand: true,
            loading: widget.busy,
            onPressed: widget.busy ? null : () => widget.onAgreed(_consents),
          )
        else
          Semantics(
            button: true,
            enabled: false,
            child: Container(
              key: const ValueKey('terms-remaining'),
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA9A4C8), width: 2),
              ),
              child: Text(
                '필수 항목 $left개에 동의해 주세요',
                style: MosiFonts.sans(
                  locale: locale,
                  size: 15,
                  weight: FontWeight.w700,
                  color: MosiColors.mutedStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, required this.size});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: checked ? MosiColors.violet : MosiColors.white,
      borderRadius: BorderRadius.circular(size * .27),
      border: Border.all(
        color: checked ? MosiColors.navy : const Color(0xFFA9A4C8),
        width: 2,
      ),
    ),
    child: checked
        ? Icon(Icons.check_rounded, size: size * .7, color: MosiColors.white)
        : null,
  );
}

class _AllAgreeCard extends StatelessWidget {
  const _AllAgreeCard({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return Semantics(
      key: const ValueKey('terms-all'),
      checked: checked,
      button: true,
      label: '전체 동의',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: checked ? const Color(0xFFEDE9FF) : MosiColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MosiColors.navy, width: 2),
            boxShadow: const [
              BoxShadow(color: MosiColors.navy, offset: Offset(4, 4)),
            ],
          ),
          child: Row(
            children: [
              _CheckBox(checked: checked, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전체 동의',
                      style: MosiFonts.sans(
                        locale: locale,
                        size: 17,
                        weight: FontWeight.w700,
                        color: MosiColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '선택 항목까지 한 번에 동의해요',
                      style: MosiFonts.sans(
                        locale: locale,
                        size: 12,
                        color: MosiColors.mutedStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    super.key,
    required this.required,
    required this.title,
    required this.sub,
    required this.checked,
    required this.onToggle,
    this.onView,
  });

  final bool required;
  final String title;
  final String sub;
  final bool checked;
  final VoidCallback? onToggle;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final tag = required ? '필수' : '선택';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              checked: checked,
              button: true,
              label: '$tag $title',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      _CheckBox(checked: checked, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: required
                                        ? const Color(0xFFFFE4E8)
                                        : const Color(0xFFEEEBF8),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    tag,
                                    style: MosiFonts.sans(
                                      locale: locale,
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: required
                                          ? const Color(0xFFB4233A)
                                          : MosiColors.mutedStrong,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      style: MosiFonts.sans(
                                        locale: locale,
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: MosiColors.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: MosiFonts.sans(
                                locale: locale,
                                size: 12,
                                color: MosiColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onView != null)
            IconButton(
              tooltip: '$title 전문 보기',
              onPressed: onView,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: MosiColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// 약관 전문을 아래에서 올라오는 시트로 보여 줍니다.
///
/// '확인하고 동의하기'를 누르면 true를 돌려줍니다.
Future<bool?> showLegalDocumentSheet(
  BuildContext context,
  LegalDocument document,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LegalDocumentSheet(document: document),
  );
}

class _LegalDocumentSheet extends StatelessWidget {
  const _LegalDocumentSheet({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final height = MediaQuery.sizeOf(context).height;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: height * .9),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: MosiColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: MosiColors.ink, width: 3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D2E8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.title,
                          style: MosiFonts.sans(
                            locale: locale,
                            size: 19,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: MosiColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Row(
                    children: [
                      Text(
                        '시행일 ${document.effectiveDate}',
                        style: MosiFonts.sans(
                          locale: locale,
                          size: 12,
                          color: MosiColors.muted,
                        ),
                      ),
                      if (document.isDraft) ...[
                        const SizedBox(width: 8),
                        const MosiPill(
                          label: '검토 전 초안',
                          background: MosiColors.sun,
                          borderColor: MosiColors.ink,
                          fontSize: 11,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    key: const ValueKey('legal-document-body'),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    children: [
                      if (document.intro != null) ...[
                        Text(
                          document.intro!,
                          style: MosiFonts.sans(
                            locale: locale,
                            size: 14,
                            color: MosiColors.ink2,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (final (heading, body) in document.sections) ...[
                        Text(
                          heading,
                          style: MosiFonts.sans(
                            locale: locale,
                            size: 15,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: MosiFonts.sans(
                            locale: locale,
                            size: 13,
                            color: MosiColors.ink2,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    12,
                    22,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE4E0F2), width: 1.5),
                    ),
                  ),
                  child: MosiButton(
                    key: const ValueKey('legal-document-agree'),
                    label: '확인하고 동의하기',
                    height: 54,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(true),
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
