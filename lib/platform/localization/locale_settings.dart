import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local display preferences only; these never change account or room data.
enum AppLanguage {
  korean('한국어', Locale('ko')),
  english('English', Locale('en')),
  simplifiedChinese(
    '简体中文',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ),
  traditionalChinese(
    '繁體中文',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  );

  const AppLanguage(this.label, this.locale);
  final String label;
  final Locale locale;
}

class LocaleSettings extends ChangeNotifier {
  static const storageKey = 'mosigame.display_preferences.v1';
  static const regions = ['KR', 'US', 'CN', 'TW', 'HK'];
  AppLanguage language = AppLanguage.korean;
  String region = 'KR';
  bool ready = false;
  bool _disposed = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is Map<String, dynamic>) {
          language =
              AppLanguage.values
                  .where((l) => l.name == value['language'])
                  .firstOrNull ??
              AppLanguage.korean;
          region = regions.contains(value['region'])
              ? value['region'] as String
              : 'KR';
        }
      }
    } catch (_) {
      // A corrupt or unavailable local preference must not block sign-in.
    }
    ready = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> save(AppLanguage nextLanguage, String nextRegion) async {
    if (!ready || !regions.contains(nextRegion)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        storageKey,
        jsonEncode({'language': nextLanguage.name, 'region': nextRegion}),
      );
      if (!saved) return false;
      language = nextLanguage;
      region = nextRegion;
      if (!_disposed) notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LocaleSettingsScope extends InheritedNotifier<LocaleSettings> {
  const LocaleSettingsScope({
    super.key,
    required LocaleSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static LocaleSettings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocaleSettingsScope>()
      ?.notifier;
}

/// Keeps the same Navigator and auth/session state when display language changes.
class LocaleSettingsHost extends StatefulWidget {
  const LocaleSettingsHost({super.key, required this.builder});
  final Widget Function(BuildContext, LocaleSettings) builder;
  @override
  State<LocaleSettingsHost> createState() => _LocaleSettingsHostState();
}

class _LocaleSettingsHostState extends State<LocaleSettingsHost> {
  final _settings = LocaleSettings();
  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleSettingsScope(
    settings: _settings,
    child: ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => widget.builder(context, _settings),
    ),
  );
}
