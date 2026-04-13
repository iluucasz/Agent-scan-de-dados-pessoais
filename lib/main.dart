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
import 'providers/settings_provider.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System tray apenas em desktop (Windows/Linux/macOS).
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await TrayService.instance.init();
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider()..checkStoredAuth()),
        ChangeNotifierProvider(create: (_) => ScanProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          // TODO(dark-mode): Feature paused for now.
          // Re-enable when continuing dark theme implementation.
          // final isDarkMode = settingsProvider.settings.darkMode;

          return MaterialApp(
            title: 'SeusDADOS Client',
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
              '/patterns': (context) => const DashboardLayout(initialIndex: 3),
              '/scan-config': (context) =>
                  const DashboardLayout(initialIndex: 1),
              '/scan-progress': (context) => const ScanProgressScreen(),
              '/scan-results': (context) => const ScanResultsScreen(),
              '/scan-history': (context) =>
                  const DashboardLayout(initialIndex: 2),
              '/settings': (context) => const DashboardLayout(initialIndex: 4),
            },
          );
        },
      ),
    );
  }
}
