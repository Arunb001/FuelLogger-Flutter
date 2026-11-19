import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'config/env_dev.dart';
import 'services/cache_service.dart';
import 'providers/auth_provider.dart';
import 'providers/garage_provider.dart';
import 'theme/app_theme.dart';
import 'views/auth/login_view.dart';
import 'views/home/home_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize DEV Environment
  EnvDev.init();

  // 2. Initialize Cache & Supabase
  await CacheService.init();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const FuelLoggerApp());
}

class FuelLoggerApp extends StatelessWidget {
  const FuelLoggerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GarageProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: AppConfig.isDev,
            theme: AppTheme.darkTheme,
            home: auth.isAuthenticated ? const HomeView() : const LoginView(),
          );
        },
      ),
    );
  }
}
