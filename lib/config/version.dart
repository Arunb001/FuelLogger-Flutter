/// Centralized Application Version Metadata for Fuel Logger
/// Maintains Semantic Versioning (SemVer) and Android Build Numbers across the entire project.
class AppVersion {
  static const String appVersion = "3.1.0";
  static const int buildNumber = 25;
  static const String buildEdition = "Release";

  /// Standard display string: "Version - 2.3.0 (Build 6)"
  static String get display => "Version - $appVersion (Build $buildNumber)";

  /// Clean display string: "Version - 2.3.0"
  static String get cleanVersion => "Version - $appVersion";

  /// Full display string
  static String get fullDisplay => "Version - $appVersion (Build $buildNumber)";
}
