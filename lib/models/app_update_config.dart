class AppUpdateConfig {
  final String platform;
  final String latestVersion;
  final int latestBuild;
  final int minSupportedBuild;
  final bool isCritical;
  final String updateTitle;
  final String updateNotes;
  final String playStoreUrl;

  const AppUpdateConfig({
    this.platform = 'android',
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    this.isCritical = false,
    this.updateTitle = 'Update Available',
    this.updateNotes = '',
    this.playStoreUrl = 'https://play.google.com/store/apps/details?id=com.fuellogger.app',
  });

  /// Effective minimum allowed build honoring critical flag and N / N-1 / N-2 window.
  int get effectiveMinSupportedBuild {
    if (isCritical) return latestBuild;
    if (minSupportedBuild > 0) return minSupportedBuild;
    return (latestBuild - 2).clamp(1, latestBuild);
  }

  factory AppUpdateConfig.fromJson(Map<String, dynamic> json) {
    final latestBuild = int.tryParse(json['latest_build']?.toString() ?? '0') ?? 0;
    final minBuild = int.tryParse(json['min_supported_build']?.toString() ?? '0') ?? 0;
    return AppUpdateConfig(
      platform: json['platform']?.toString() ?? 'android',
      latestVersion: json['latest_version']?.toString() ?? '',
      latestBuild: latestBuild,
      minSupportedBuild: minBuild,
      isCritical: json['is_critical'] == true,
      updateTitle: (json['update_title']?.toString().trim().isNotEmpty == true)
          ? json['update_title'].toString().trim()
          : 'Update Available',
      updateNotes: json['update_notes']?.toString().trim() ?? '',
      playStoreUrl: (json['play_store_url']?.toString().trim().isNotEmpty == true)
          ? json['play_store_url'].toString().trim()
          : 'https://play.google.com/store/apps/details?id=com.fuellogger.app',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'latest_version': latestVersion,
      'latest_build': latestBuild,
      'min_supported_build': minSupportedBuild,
      'is_critical': isCritical,
      'update_title': updateTitle,
      'update_notes': updateNotes,
      'play_store_url': playStoreUrl,
    };
  }
}
