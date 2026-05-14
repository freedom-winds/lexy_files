import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight, asset-backed localization layer for Lexy Files.
///
/// All translation strings ship as JSON files under `assets/i18n/<code>.json`
/// and are bundled with the executable, so the app keeps working when the
/// device has no internet (LAN/Bluetooth/offline modes).
///
/// Supported languages: English (`en`), Chinese (`zh`) and French (`fr`).
/// English is the fallback for any unsupported locale.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// All keys live in this map after [load] resolves.
  Map<String, String> _strings = const {};

  /// Static list of locales the UI offers.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('fr'),
  ];

  /// Localization delegate to feed into `MaterialApp`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Convenience accessor: `AppLocalizations.of(context).t('home.title')`.
  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(
      loc != null,
      'AppLocalizations not found in context. Did you forget '
      '`MaterialApp.localizationsDelegates`?',
    );
    return loc!;
  }

  /// Returns the language tag we use in asset filenames (`en`, `zh`, `fr`).
  String get _resolvedTag => _resolveTag(locale.languageCode);

  static String _resolveTag(String code) {
    switch (code) {
      case 'zh':
      case 'fr':
      case 'en':
        return code;
      default:
        return 'en';
    }
  }

  Future<void> _load() async {
    final tag = _resolvedTag;
    try {
      final raw = await rootBundle.loadString('assets/i18n/$tag.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _strings = decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e, stack) {
      debugPrint('[AppLocalizations] failed to load $tag.json: $e\n$stack');
      // Fall back to English if a localized bundle is missing/corrupt.
      if (tag != 'en') {
        try {
          final raw = await rootBundle.loadString('assets/i18n/en.json');
          final decoded = json.decode(raw) as Map<String, dynamic>;
          _strings = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {
          _strings = const {};
        }
      }
    }
  }

  /// Translate `key`, optionally substituting `{placeholder}` tokens with the
  /// supplied [params]. Falls back to the key itself if missing — that makes
  /// missing strings obvious during development without crashing the UI.
  String t(String key, {Map<String, Object?> params = const {}}) {
    var value = _strings[key] ?? key;
    if (params.isNotEmpty) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v?.toString() ?? '');
      });
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations(locale);
    await loc._load();
    return loc;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience extension so screens can write `context.l10n.t('home.title')`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
