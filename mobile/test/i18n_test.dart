// Tests for the asset-backed AppLocalizations layer.
//
// These tests deliberately avoid spinning up a `MaterialApp` so they catch
// missing keys / asset registration before the rest of the UI is even
// touched. Run with:
//
//   flutter test test/i18n_test.dart

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lexy_files/l10n/app_localizations.dart';

/// Keys every locale must define. Keep this list small but representative —
/// these are the strings the user sees the moment the app boots.
const _criticalKeys = <String>[
  'appName',
  'nav.home',
  'nav.files',
  'nav.devices',
  'nav.transfer',
  'auth.signIn',
  'auth.signOut',
  'home.title',
  'home.subtitle',
  'home.chooseFile',
  'files.title',
  'devices.title',
  'transfer.title',
  'settings.language',
  'settings.systemDefault',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLocalizations bundles', () {
    for (final code in const ['en', 'zh', 'fr']) {
      test('$code.json is bundled and parses', () async {
        final raw = await rootBundle.loadString('assets/i18n/$code.json');
        final decoded = json.decode(raw);

        expect(decoded, isA<Map<String, dynamic>>());

        final map = decoded as Map<String, dynamic>;
        for (final key in _criticalKeys) {
          expect(
            map.containsKey(key),
            isTrue,
            reason: 'Locale "$code" is missing critical key "$key"',
          );
          expect(
            (map[key] as String).trim(),
            isNotEmpty,
            reason: 'Locale "$code" has empty value for "$key"',
          );
        }
      });
    }
  });

  group('AppLocalizations resolution', () {
    test('translates English keys', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      expect(loc.t('home.title'), 'Home');
      expect(loc.t('nav.transfer'), 'Transfer');
    });

    test('translates Chinese keys', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(loc.t('home.title'), '首页');
      expect(loc.t('nav.transfer'), '传输');
    });

    test('translates French keys', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(loc.t('home.title'), 'Accueil');
      expect(loc.t('nav.transfer'), 'Transfert');
    });

    test('falls back to English for unsupported locales', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('xx'));
      expect(loc.t('home.title'), 'Home');
    });

    test('substitutes {placeholders} from params', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      final result = loc.t('files.subtitle', params: {'count': 1});
      expect(result, '1 file in your library.');
    });

    test('returns the key itself when no translation is found', () async {
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      expect(loc.t('nonsense.key.does.not.exist'), 'nonsense.key.does.not.exist');
    });

    test('isSupported recognizes all bundled locales', () {
      expect(
        AppLocalizations.delegate.isSupported(const Locale('en')),
        isTrue,
      );
      expect(
        AppLocalizations.delegate.isSupported(const Locale('zh')),
        isTrue,
      );
      expect(
        AppLocalizations.delegate.isSupported(const Locale('fr')),
        isTrue,
      );
      expect(
        AppLocalizations.delegate.isSupported(const Locale('jp')),
        isFalse,
      );
    });
  });
}
