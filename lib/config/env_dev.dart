import 'env.dart';

class EnvDev {
  static void init() {
    AppConfig.appName = "Fuel Logger (DEV)";
    AppConfig.supabaseUrl = "https://qjwuajdcyrdlnjplvtsr.supabase.co";
    AppConfig.supabaseAnonKey = "sb_publishable_GPeXnnny-P77oi3GRmLdeg_8XNmDiKr";
    AppConfig.isDev = true;
    AppConfig.flavor = "dev";
    AppConfig.googleWebClientId = null;
  }
}
