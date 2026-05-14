import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _kPrefKey = 'app_locale_override';

/// Owns the active [Locale] for the app.
///
/// Boot order:
/// 1. If the user has previously picked a language, use that.
/// 2. Otherwise pick the closest match to the platform locale
///    (e.g. `zh-CN` → `zh`, `fr-CA` → `fr`).
/// 3. Fall back to English.
///
/// Calling [setLocale] persists the choice locally (no network needed) and
/// notifies listeners so `MaterialApp` rebuilds in the new language.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    _bootstrap();
  }

  Locale? _locale;
  bool _ready = false;

  /// Active locale, or `null` while we're still hydrating from prefs.
  Locale? get locale => _locale;

  /// `true` when the locale has been resolved at least once. Until this is
  /// `true`, the app should keep its launch screen on screen.
  bool get isReady => _ready;

  /// `true` if the user has explicitly chosen a locale (vs. system-following).
  bool _userOverride = false;
  bool get isUserOverride => _userOverride;

  Future<void> _bootstrap() async {
    final prefs = SharedPreferencesAsync();
    final saved = await prefs.getString(_kPrefKey);

    if (saved != null && saved.isNotEmpty) {
      _userOverride = true;
      _locale = Locale(saved);
    } else {
      _userOverride = false;
      _locale = _detectFromPlatform();
    }
    _ready = true;
    notifyListeners();
  }

  /// Pick the best locale we support based on the platform's preferences.
  Locale _detectFromPlatform() {
    final preferred = PlatformDispatcher.instance.locales;
    final supportedCodes = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();

    for (final loc in preferred) {
      if (supportedCodes.contains(loc.languageCode)) {
        return Locale(loc.languageCode);
      }
    }
    return const Locale('en');
  }

  /// Explicitly switch to [code] (`'en' | 'zh' | 'fr'`).
  Future<void> setLocale(String code) async {
    final supported = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == code);
    if (!supported) {
      debugPrint('[LocaleProvider] ignored unsupported locale: $code');
      return;
    }
    _locale = Locale(code);
    _userOverride = true;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setString(_kPrefKey, code);
  }

  /// Drop the user override and follow the system locale again.
  Future<void> useSystemDefault() async {
    _userOverride = false;
    _locale = _detectFromPlatform();
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.remove(_kPrefKey);
  }
}
