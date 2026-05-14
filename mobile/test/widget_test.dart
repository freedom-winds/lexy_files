import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:lexy_files/config/theme.dart';
import 'package:lexy_files/l10n/app_localizations.dart';
import 'package:lexy_files/providers/auth_provider.dart';
import 'package:lexy_files/providers/locale_provider.dart';
import 'package:lexy_files/providers/navigation_provider.dart';
import 'package:lexy_files/services/api_service.dart';
import 'package:lexy_files/services/device_presence_service.dart';
import 'package:lexy_files/widgets/app_shell.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Dark navy theme renders with cyan accent', (tester) async {
    final apiService = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          Provider<DevicePresenceService>(
            create: (_) => DevicePresenceService(apiService),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(apiService),
          ),
          ChangeNotifierProvider<NavigationProvider>(
            create: (_) => NavigationProvider(),
          ),
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(),
        ),
      ),
    );

    // Two pumps so the AppLocalizations delegate finishes loading the JSON
    // bundle before we assert.
    await tester.pump();
    await tester.pump();

    // Material app builds
    expect(find.byType(MaterialApp), findsOneWidget);

    // Theme tokens match the Windows design reference.
    expect(AppTheme.bgPage, const Color(0xFF051424));
    expect(AppTheme.accentColor, const Color(0xFF00F0FF));
    expect(AppTheme.surfaceColor, const Color(0xFF122131));
  });

  test('Theme exposes the expected design tokens', () {
    expect(AppTheme.radiusLg, 14);
    expect(AppTheme.sidebarWidth, 248);
    expect(AppTheme.accentGlow(alpha: 0.5).length, 1);
  });
}
