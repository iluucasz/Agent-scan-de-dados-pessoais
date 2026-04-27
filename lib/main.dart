import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_layout.dart';
import 'screens/components_demo_screen.dart';
import 'screens/scan_progress_screen.dart';
import 'screens/scan_results_screen.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/settings_provider.dart';
import 'services/tray_service.dart';
import 'services/notification_service.dart';
import 'services/logging_service.dart';
import 'models/log_entry.dart';

String? _extractProvisioningToken(List<String> args) {
  for (var index = 0; index < args.length; index++) {
    final arg = args[index].trim();
    if (arg.isEmpty) {
      continue;
    }

    final normalizedArg = arg.toLowerCase();
    if (normalizedArg.startsWith('/token=')) {
      final token = arg.substring('/token='.length).trim();
      return token.isEmpty ? null : token;
    }

    if (normalizedArg.startsWith('--token=')) {
      final token = arg.substring('--token='.length).trim();
      return token.isEmpty ? null : token;
    }

    if ((normalizedArg == '/token' || normalizedArg == '--token') &&
        index + 1 < args.length) {
      final token = args[index + 1].trim();
      return token.isEmpty ? null : token;
    }
  }

  return null;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final provisioningToken = _extractProvisioningToken(args);

  // System tray e notificações apenas em desktop (Windows/Linux/macOS).
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await TrayService.instance.init();
    await NotificationService.instance.init();
  }

  // Log de inicialização do app
  LoggingService.instance.info(
    LogCategory.execution,
    'Aplicação iniciada',
    details:
        'SeusDADOS Client iniciado em ${Platform.operatingSystem}; provisioningToken=${provisioningToken != null}',
  );

  runApp(MainApp(provisioningToken: provisioningToken));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.provisioningToken});

  final String? provisioningToken;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider()
              ..initialize(provisioningToken: provisioningToken)),
        ChangeNotifierProvider(create: (_) => ScanProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          // TODO(dark-mode): Feature paused for now.
          // Re-enable when continuing dark theme implementation.
          // final isDarkMode = settingsProvider.settings.darkMode;

          return MaterialApp(
            title: 'PrivacyPulse',
            theme: AppTheme.lightTheme,
            // darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                // Enquanto verifica autenticação, mostrar splash
                if (authProvider.isLoading) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Navegar para tela correta baseado na autenticação
                if (authProvider.isAuthenticated) {
                  return const DashboardLayout(initialIndex: 0);
                } else {
                  return const LoginScreen();
                }
              },
            ),
            routes: {
              '/dashboard': (context) => const DashboardLayout(initialIndex: 0),
              '/login': (context) => const LoginScreen(),
              '/components-demo': (context) => const ComponentsDemoScreen(),
              '/scan-config': (context) =>
                  const DashboardLayout(initialIndex: 1),
              '/schedule': (context) => const DashboardLayout(initialIndex: 2),
              '/scan-history': (context) =>
                  const DashboardLayout(initialIndex: 3),
              '/logs': (context) => const DashboardLayout(initialIndex: 4),
              '/patterns': (context) => const DashboardLayout(initialIndex: 5),
              '/settings': (context) => const DashboardLayout(initialIndex: 6),
              '/scan-progress': (context) => const ScanProgressScreen(),
              '/scan-results': (context) => const ScanResultsScreen(),
            },
          );
        },
      ),
    );
  }
}
