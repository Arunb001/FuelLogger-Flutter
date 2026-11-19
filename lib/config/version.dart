/// Centralized Application Version Metadata for Fuel Logger
/// Maintains Semantic Versioning (SemVer) and Android Build Numbers across the entire project.
class AppVersion {
  static const String appVersion = "2.2.0";
  static const int buildNumber = 5;
  static const String buildEdition = "Flutter Native Edition";

  /// Standard display string: "Version 2.2.0 (Build 5)"
  static String get display => "Version $appVersion (Build $buildNumber)";

  /// Full display string: "Version 2.2.0 (Build 5) • Flutter Native Edition"
  static String get fullDisplay => "Version $appVersion (Build $buildNumber) • $buildEdition";
}
