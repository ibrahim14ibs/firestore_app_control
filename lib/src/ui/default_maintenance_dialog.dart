import 'package:flutter/material.dart';
import '../models/app_config.dart';

/// Modal dialog display for Maintenance Mode that prevents back navigation.
class DefaultMaintenanceDialog extends StatelessWidget {
  final MaintenanceConfig maintenance;
  final VoidCallback onRetry;
  final Color? primaryColor;

  const DefaultMaintenanceDialog({
    super.key,
    required this.maintenance,
    required this.onRetry,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final effectivePrimary = primaryColor ?? theme.colorScheme.primary;

    final title = isArabic
        ? (maintenance.titleAr.trim().isNotEmpty
            ? maintenance.titleAr
            : 'التطبيق قيد الصيانة')
        : (maintenance.titleEn.trim().isNotEmpty
            ? maintenance.titleEn
            : 'App Under Maintenance');

    final message = isArabic
        ? (maintenance.messageAr.trim().isNotEmpty
            ? maintenance.messageAr
            : 'نقوم حاليًا ببعض التحسينات، يرجى المحاولة لاحقًا.')
        : (maintenance.messageEn.trim().isNotEmpty
            ? maintenance.messageEn
            : 'We are currently performing improvements. Please try again later.');

    final retryLabel = isArabic ? 'التحقق مرة أخرى' : 'Check Again';

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 10,
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
                child: Icon(
                  Icons.build_circle_rounded,
                  size: 36,
                  color: effectivePrimary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  label: Text(
                    retryLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectivePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
