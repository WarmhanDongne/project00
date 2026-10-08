import 'package:flutter/widgets.dart';
import 'package:project00/generated/l10n/app_localizations.dart';
import 'package:project00/generated/l10n/app_localizations_ko.dart';

extension PlatformLocalizations on BuildContext {
  // Isolated previews/tests without the app shell retain the original Korean UI.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsKo();
}
