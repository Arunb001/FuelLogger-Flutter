import 'env.dart';

class EnvProd {
  static void init() {
    AppConfig.appName = "Fuel Logger";
    AppConfig.supabaseUrl = "https://hjprefmnofrqyjocihto.supabase.co";
    AppConfig.supabaseAnonKey = "sb_publishable_lNx5b9ACw-1kAsRtWaQ4-Q_TDoA-JoD";
    AppConfig.isDev = false;
    AppConfig.flavor = "prod";
    AppConfig.googleWebClientId = "376743404421-kuj7117qutn4svh9lff4o3i97tom44br.apps.googleusercontent.com";
  }
}
