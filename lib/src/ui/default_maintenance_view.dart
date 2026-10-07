import 'package:flutter/material.dart';
import '../models/app_config.dart';

class DefaultMaintenanceView extends StatelessWidget {
  final MaintenanceConfig maintenance;
  final VoidCallback onRetry;
  final Color? primaryColor;

  const DefaultMaintenanceView({
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: effectivePrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.build_circle_rounded,
                        size: 64,
                        color: effectivePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ) ??
                        TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      label: Text(
                        retryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectivePrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
