import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/env.dart';
import 'providers/auth_provider.dart';
import 'providers/garage_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'views/auth/login_view.dart';
import 'views/shell/main_shell.dart';

class FuelLoggerApp extends StatelessWidget {
  const FuelLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GarageProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: AppConfig.isDev,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            home: auth.isAuthenticated ? const MainShell() : const LoginView(),
          );
        },
      ),
    );
  }
}
