import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';
import '../config/version.dart';
import '../services/update_checker_service.dart';
import '../theme/app_theme.dart';

class UpdateDialog {
  static bool _promptedThisSession = false;

  static void resetSessionFlag() {
    _promptedThisSession = false;
  }

  static Future<void> checkAndShow(BuildContext context) async {
    if (_promptedThisSession) return;

    final result = await UpdateCheckerService.checkForUpdate(
      installedBuild: AppVersion.buildNumber,
    );

    if (!result.needsPrompt || result.config == null || !context.mounted) {
      return;
    }

    _promptedThisSession = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !result.isForce,
      builder: (ctx) => _UpdatePromptDialog(result: result),
    );
  }
}

class _UpdatePromptDialog extends StatelessWidget {
  final UpdateCheckResult result;

  const _UpdatePromptDialog({required this.result});

  Future<void> _openStore(String url) async {
    final playMarketUri = Uri.parse('market://details?id=com.fuellogger.app');
    final webUri = Uri.parse(url);
    try {
      if (await canLaunchUrl(playMarketUri)) {
        await launchUrl(playMarketUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = result.config!;
    final isForce = result.isForce;
    final accent = isForce ? AppTheme.primary : AppTheme.distanceBlue;

    return PopScope(
      canPop: !isForce,
      child: AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color ?? AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isForce ? Icons.system_update : Icons.new_releases_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isForce ? 'Update Required' : cfg.updateTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isForce
                  ? 'This version (Build ${result.installedBuild}) is no longer supported. Please update to v${cfg.latestVersion} (Build ${cfg.latestBuild}) to continue.'
                  : 'Version ${cfg.latestVersion} (Build ${cfg.latestBuild}) is available on Google Play.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            if (cfg.updateNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  cfg.updateNotes,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
          if (isForce && AppConfig.isDev)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Bypass (DEV Test)',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => _openStore(cfg.playStoreUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
