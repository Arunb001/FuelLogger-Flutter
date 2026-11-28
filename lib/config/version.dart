/// Centralized Application Version Metadata for Fuel Logger
/// Maintains Semantic Versioning (SemVer) and Android Build Numbers across the entire project.
class AppVersion {
  static const String appVersion = "3.2.1";
  static const int buildNumber = 27;
  static const String buildEdition = "Release";

  /// Standard display string: "Fuel Logger - 3.2.0 (26)"
  static String get display => "Fuel Logger - $appVersion ($buildNumber)";

  /// Clean display string: "Version - 3.2.0"
  static String get cleanVersion => "Version - $appVersion";

  /// Full display string: "Fuel Logger - 3.2.0 (26)"
  static String get fullDisplay => "Fuel Logger - $appVersion ($buildNumber)";
}
