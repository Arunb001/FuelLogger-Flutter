import 'dart:async';
import '../models/app_update_config.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

enum UpdateRequirement {
  upToDate,
  optionalUpdate,
  forceUpdate,
}

class UpdateCheckResult {
  final UpdateRequirement requirement;
  final AppUpdateConfig? config;
  final int installedBuild;

  const UpdateCheckResult({
    required this.requirement,
    required this.installedBuild,
    this.config,
  });

  bool get needsPrompt => requirement != UpdateRequirement.upToDate;
  bool get isForce => requirement == UpdateRequirement.forceUpdate;
}

class UpdateCheckerService {
  /// Evaluates installed build number against remote config:
  /// - Forced if [installedBuild] < [config.effectiveMinSupportedBuild] (critical OR > 2 versions behind)
  /// - Optional if [installedBuild] < [config.latestBuild] (1 to 2 versions behind)
  /// - Up to date otherwise.
  static UpdateRequirement evaluate(int installedBuild, AppUpdateConfig config) {
    if (config.latestBuild <= 0) return UpdateRequirement.upToDate;

    final minBuild = config.effectiveMinSupportedBuild;
    if (installedBuild < minBuild) {
      return UpdateRequirement.forceUpdate;
    }
    if (installedBuild < config.latestBuild) {
      return UpdateRequirement.optionalUpdate;
    }
    return UpdateRequirement.upToDate;
  }

  /// Checks `public.app_config` in Supabase with a short timeout and safe offline handling.
  /// Never blocks offline users unless a previously cached verified config already flagged this build.
  static Future<UpdateCheckResult> checkForUpdate({
    required int installedBuild,
    String platform = 'android',
  }) async {
    try {
      final res = await SupabaseService.client
          .from('app_config')
          .select()
          .eq('platform', platform)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (res != null) {
        final config = AppUpdateConfig.fromJson(res);
        await CacheService.saveCachedUpdateConfig(config);
        return UpdateCheckResult(
          requirement: evaluate(installedBuild, config),
          installedBuild: installedBuild,
          config: config,
        );
      }
    } catch (_) {
      // Offline / unmigrated fallback: respect cached config only if it requires a forced update
      final cached = CacheService.getCachedUpdateConfig();
      if (cached != null && evaluate(installedBuild, cached) == UpdateRequirement.forceUpdate) {
        return UpdateCheckResult(
          requirement: UpdateRequirement.forceUpdate,
          installedBuild: installedBuild,
          config: cached,
        );
      }
    }

    return UpdateCheckResult(
      requirement: UpdateRequirement.upToDate,
      installedBuild: installedBuild,
    );
  }
}
