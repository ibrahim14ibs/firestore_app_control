import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_config.dart';
import '../utils/app_control_logger.dart';

/// Floating in-stack SnackBar / banner for optional updates.
///
/// Displayed at the bottom of the screen without blocking interaction with the rest
/// of the application.
class DefaultOptionalUpdateSnackBar extends StatelessWidget {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final VoidCallback onDismiss;
  final Color? primaryColor;

  const DefaultOptionalUpdateSnackBar({
    super.key,
    required this.platformConfig,
    required this.currentVersion,
    required this.onDismiss,
    this.primaryColor,
  });

  Future<void> _openStore(BuildContext context) async {
    final rawUrl = platformConfig.storeUrl.trim();
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final errorMsg = isArabic
        ? 'تعذر فتح متجر التطبيقات'
        : 'Unable to open app store';

    if (rawUrl.isEmpty) {
      AppControlLogger.warning('Cannot open store: storeUrl is empty.');
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      AppControlLogger.warning('Cannot open store: invalid URI "$rawUrl".');
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
      return;
    }

    AppControlLogger.info('Launching store URL: "$rawUrl"...');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        AppControlLogger.info('Successfully launched store URL: "$rawUrl".');
        onDismiss();
      } else {
        AppControlLogger.warning('launchUrl returned false for store URL: "$rawUrl".');
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e, stackTrace) {
      AppControlLogger.error(
        'Exception while launching store URL "$rawUrl": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final effectivePrimary = primaryColor ?? theme.colorScheme.primary;

    final title = isArabic ? 'تحديث متوفر' : 'Update Available';
    final updateBtn = isArabic ? 'تحديث' : 'Update';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: effectivePrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update_alt_rounded,
                size: 24,
                color: effectivePrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v$currentVersion → v${platformConfig.latestVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _openStore(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: effectivePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                updateBtn,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
              onPressed: onDismiss,
              tooltip: isArabic ? 'إغلاق' : 'Close',
              splashRadius: 18,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
      ),
    );
  }
}
