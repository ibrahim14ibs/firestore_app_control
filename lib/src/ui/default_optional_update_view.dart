import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_config.dart';

/// Full-screen view for optional updates with a dismiss/continue button.
class DefaultOptionalUpdateView extends StatefulWidget {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final VoidCallback onDismiss;
  final Color? primaryColor;

  const DefaultOptionalUpdateView({
    super.key,
    required this.platformConfig,
    required this.currentVersion,
    required this.onDismiss,
    this.primaryColor,
  });

  @override
  State<DefaultOptionalUpdateView> createState() => _DefaultOptionalUpdateViewState();
}

class _DefaultOptionalUpdateViewState extends State<DefaultOptionalUpdateView> {
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
      if (launched) {
        widget.onDismiss();
      } else if (mounted) {
        setState(() => _errorMessage = fallbackError);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = fallbackError);
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

    final title = isArabic ? 'يتوفر إصدار جديد من التطبيق' : 'New Version Available';
    final message = isArabic
        ? 'يتوفر إصدار أحدث يقدم مميزات وتحسينات جديدة. هل ترغب بالتحديث الآن؟'
        : 'A newer version with improvements is available. Would you like to update now?';
    final updateLabel = isArabic ? 'تحديث الآن' : 'Update Now';
    final laterLabel = isArabic ? 'لاحقًا ومتابعة الاستخدام' : 'Later, Continue to App';

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
                        Icons.system_update_alt_rounded,
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
                      'v${widget.currentVersion} → v${widget.platformConfig.latestVersion}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLaunching ? null : () => _openStore(isArabic),
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, color: Colors.white),
                      label: Text(
                        updateLabel,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(
                        laterLabel,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
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
