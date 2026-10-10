import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'locale_settings.dart';
import 'platform_localizations.dart';

class LocaleSettingsButton extends StatelessWidget {
  const LocaleSettingsButton({super.key, this.darkBackground = true});
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final settings = LocaleSettingsScope.maybeOf(context);
    return IconButton(
      tooltip: context.l10n.regionLanguage,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: darkBackground ? Colors.transparent : MosiColors.navy,
      ),
      icon: const Icon(Icons.language, color: MosiColors.white, size: 28),
      onPressed: settings?.ready != true
          ? null
          : () => showMosiDialog<void>(
              context: context,
              // 누른 버튼 자리에서 펼쳐지고 같은 자리로 접힙니다(로비 연출 8번).
              origin: mosiOriginOf(context),
              barrierDismissible: false,
              builder: (_) => LocaleSettingsDialog(settings: settings!),
            ),
    );
  }
}

class LocaleSettingsDialog extends StatefulWidget {
  const LocaleSettingsDialog({super.key, required this.settings});
  final LocaleSettings settings;
  @override
  State<LocaleSettingsDialog> createState() => _LocaleSettingsDialogState();
}

class _LocaleSettingsDialogState extends State<LocaleSettingsDialog> {
  late AppLanguage _language = widget.settings.language;
  late String _region = widget.settings.region;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await widget.settings.save(_language, _region);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final regionLabels = {
      'KR': t.regionKR,
      'US': t.regionUS,
      'CN': t.regionCN,
      'TW': t.regionTW,
      'HK': t.regionHK,
    };
    final style = MosiFonts.sans(
      locale: Localizations.localeOf(context),
      color: MosiColors.navy,
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical -
                32,
          ),
          child: MosiDialogFrame(
            width: null,
            padding: const EdgeInsets.all(20),
            semanticLabel: t.regionLanguage,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.regionLanguage,
                          style: style.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: t.close,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: MosiColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<AppLanguage>(
                    key: const Key('display-language'),
                    initialValue: _language,
                    isExpanded: true,
                    style: style,
                    decoration: mosiInputDecoration().copyWith(
                      labelText: t.language,
                    ),
                    items: AppLanguage.values
                        .map(
                          (language) => DropdownMenuItem(
                            value: language,
                            child: Text(
                              language.label,
                              style: MosiFonts.sans(
                                locale: language.locale,
                                color: MosiColors.navy,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _language = value!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: const Key('display-region'),
                    initialValue: _region,
                    isExpanded: true,
                    style: style,
                    decoration: mosiInputDecoration().copyWith(
                      labelText: t.region,
                    ),
                    items: regionLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _region = value!),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.regionHint,
                    style: style.copyWith(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.translationScope,
                    style: style.copyWith(fontSize: 13, height: 1.5),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        t.saveFailed,
                        style: style.copyWith(color: MosiColors.red),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: MosiButton(
                          label: t.cancel,
                          background: MosiColors.white,
                          expand: true,
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MosiButton(
                          label: t.save,
                          expand: true,
                          loading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
