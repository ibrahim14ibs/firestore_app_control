import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_config.dart';
import '../utils/app_control_logger.dart';

/// Modal dialog display for Force Update that prevents back navigation and exit.
class DefaultForceUpdateDialog extends StatefulWidget {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final bool isOffline;
  final VoidCallback onRetry;
  final Color? primaryColor;

  const DefaultForceUpdateDialog({
    super.key,
    required this.platformConfig,
    required this.currentVersion,
    this.isOffline = false,
    required this.onRetry,
    this.primaryColor,
  });

  @override
  State<DefaultForceUpdateDialog> createState() => _DefaultForceUpdateDialogState();
}

class _DefaultForceUpdateDialogState extends State<DefaultForceUpdateDialog> {
  bool _isLaunching = false;
  String? _errorMessage;

  Future<void> _openStore(bool isArabic) async {
    final rawUrl = widget.platformConfig.storeUrl.trim();
    final fallbackError = isArabic
        ? 'تعذر فتح متجر التطبيقات'
        : 'Unable to open app store';

    if (rawUrl.isEmpty) {
      AppControlLogger.warning('Cannot open store: storeUrl is empty.');
      setState(() => _errorMessage = fallbackError);
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      AppControlLogger.warning('Cannot open store: invalid URI "$rawUrl".');
      setState(() => _errorMessage = fallbackError);
      return;
    }

    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    AppControlLogger.info('Launching store URL: "$rawUrl"...');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppControlLogger.warning('launchUrl returned false for store URL: "$rawUrl".');
        setState(() => _errorMessage = fallbackError);
      } else {
        AppControlLogger.info('Successfully launched store URL: "$rawUrl".');
      }
    } catch (e, stackTrace) {
      AppControlLogger.error(
        'Exception while launching store URL "$rawUrl": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _errorMessage = widget.isOffline
              ? (isArabic
                  ? 'يتطلب استخدام التطبيق تحديثه. تحقق من الاتصال بالإنترنت.'
                  : 'Update required. Please check your internet connection.')
              : fallbackError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final effectivePrimary = widget.primaryColor ?? theme.colorScheme.primary;

    final title = isArabic ? 'هناك إصدار جديد مطلوب' : 'Update Required';
    final message = widget.isOffline
        ? (isArabic
            ? 'يتطلب استخدام التطبيق تحديثه إلى أحدث إصدار. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.'
            : 'The app requires updating to the latest version. Please check internet connection.')
        : (isArabic
            ? 'يرجى تحديث التطبيق للاستمرار في استخدامه.'
            : 'Please update the app to continue using it.');
    final buttonLabel = isArabic ? 'تحديث الآن' : 'Update Now';
    final retryLabel = isArabic ? 'إعادة الفحص' : 'Check Again';

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
                  Icons.system_update_rounded,
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
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'v${widget.currentVersion} → v${widget.platformConfig.minimumVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isLaunching ? null : () => _openStore(isArabic),
                  icon: _isLaunching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  label: Text(
                    buttonLabel,
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onRetry,
                child: Text(
                  retryLabel,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
