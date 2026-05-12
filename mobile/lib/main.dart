import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'services/device_presence_service.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/pickup_screen.dart';
import 'screens/design_preview_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<DevicePresenceService>(
          create: (_) => DevicePresenceService(apiService),
          dispose: (_, service) => service.stop(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiService),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: const _PresenceController(child: LexyFilesApp()),
    ),
  );
}

class LexyFilesApp extends StatelessWidget {
  const LexyFilesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lexy Files',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthGate(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/pickup':
            final code = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => PickupScreen(code: code));
          case '/design-preview':
            return MaterialPageRoute(
              builder: (_) => const DesignPreviewScreen(),
            );
          default:
            return MaterialPageRoute(builder: (_) => const AppShell());
        }
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const AppShell();
  }
}

class _PresenceController extends StatefulWidget {
  const _PresenceController({required this.child});

  final Widget child;

  @override
  State<_PresenceController> createState() => _PresenceControllerState();
}

class _PresenceControllerState extends State<_PresenceController> {
  bool _presenceStarted = false;
  DevicePresenceService? _presence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    _presence = context.read<DevicePresenceService>();

    if (auth.isLoading) return;

    if (auth.isAuthenticated) {
      if (!_presenceStarted) {
        _presenceStarted = true;
        unawaited(_presence!.ensureStarted());
      }
    } else if (_presenceStarted) {
      _presenceStarted = false;
      _presence!.stop();
    }
  }

  @override
  void dispose() {
    _presence?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
