import 'env.dart';

class EnvDev {
  static void init() {
    AppConfig.appName = "Fuel Logger (DEV)";
    AppConfig.supabaseUrl = "https://qjwuajdcyrdlnjplvtsr.supabase.co";
    AppConfig.supabaseAnonKey = "sb_publishable_GPeXnnny-P77oi3GRmLdeg_8XNmDiKr";
    AppConfig.isDev = true;
    AppConfig.flavor = "dev";
    AppConfig.googleWebClientId = "376743404421-m2qcvgn1r17rkefqdl541o7lh8q8fnrn.apps.googleusercontent.com";
  }
}
