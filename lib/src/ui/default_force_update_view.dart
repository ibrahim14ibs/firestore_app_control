import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_config.dart';

class DefaultForceUpdateView extends StatefulWidget {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final bool isOffline;
  final VoidCallback onRetry;
  final Color? primaryColor;

  const DefaultForceUpdateView({
    super.key,
    required this.platformConfig,
    required this.currentVersion,
    this.isOffline = false,
    required this.onRetry,
    this.primaryColor,
  });

  @override
  State<DefaultForceUpdateView> createState() => _DefaultForceUpdateViewState();
}

class _DefaultForceUpdateViewState extends State<DefaultForceUpdateView> {
  bool _isLaunching = false;
  String? _errorMessage;

  Future<void> _openStore(bool isArabic) async {
    final rawUrl = widget.platformConfig.storeUrl.trim();
    final fallbackError = isArabic
        ? 'تعذر فتح متجر التطبيقات'
        : 'Unable to open app store';

    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = fallbackError);
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      setState(() => _errorMessage = fallbackError);
      return;
    }

    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _errorMessage = fallbackError);
      }
    } catch (_) {
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
            ? 'يرجى تحديث التطبيق للاستمرار.'
            : 'Please update the app to continue using it.');
    final buttonLabel = isArabic ? 'تحديث الآن' : 'Update Now';

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
                        Icons.system_update_rounded,
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v${widget.currentVersion} → v${widget.platformConfig.minimumVersion}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLaunching ? null : () => _openStore(isArabic),
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                      label: Text(
                        buttonLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  if (widget.isOffline || _errorMessage != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(
                        isArabic ? 'إعادة المحاولة' : 'Try Again',
                        style: TextStyle(color: effectivePrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
