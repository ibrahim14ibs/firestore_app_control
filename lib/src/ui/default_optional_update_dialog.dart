import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_config.dart';

class DefaultOptionalUpdateDialog extends StatelessWidget {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final VoidCallback onDismiss;
  final Color? primaryColor;

  const DefaultOptionalUpdateDialog({
    super.key,
    required this.platformConfig,
    required this.currentVersion,
    required this.onDismiss,
    this.primaryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required PlatformConfig platformConfig,
    required String currentVersion,
    required VoidCallback onDismiss,
    Color? primaryColor,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DefaultOptionalUpdateDialog(
        platformConfig: platformConfig,
        currentVersion: currentVersion,
        onDismiss: onDismiss,
        primaryColor: primaryColor,
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final rawUrl = platformConfig.storeUrl.trim();
    if (rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final effectivePrimary = primaryColor ?? theme.colorScheme.primary;

    final title = isArabic ? 'يتوفر إصدار جديد من التطبيق' : 'New Version Available';
    final message = isArabic
        ? 'هل ترغب في تحديث التطبيق الآن؟'
        : 'A new version of the app is available. Would you like to update now?';
    final updateBtn = isArabic ? 'تحديث الآن' : 'Update Now';
    final laterBtn = isArabic ? 'لاحقًا' : 'Later';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: effectivePrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.system_update_alt_rounded, size: 36, color: effectivePrimary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'v$currentVersion → v${platformConfig.latestVersion}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      onDismiss();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(laterBtn, style: TextStyle(color: Colors.grey.shade700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: effectivePrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(updateBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
