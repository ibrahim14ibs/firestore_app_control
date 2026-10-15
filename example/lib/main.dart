import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestore_app_control/firestore_app_control.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the CLI-generated options for fir-app-control-ff3e2
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/error: $e');
  }

  runApp(const ExampleApp());
}

/// Model holding interactive showcase configuration options.
class ExampleSettings {
  final String simulatedVersion;
  final AppControlDisplayMode maintenanceDisplayMode;
  final AppControlDisplayMode forceUpdateDisplayMode;
  final OptionalUpdateDisplayMode optionalUpdateDisplayMode;
  final bool useCustomBuilders;
  final bool autoShowOptionalUpdate;
  final bool enableLogging;

  const ExampleSettings({
    this.simulatedVersion = '1.0.0',
    this.maintenanceDisplayMode = AppControlDisplayMode.fullScreen,
    this.forceUpdateDisplayMode = AppControlDisplayMode.fullScreen,
    this.optionalUpdateDisplayMode = OptionalUpdateDisplayMode.dialog,
    this.useCustomBuilders = false,
    this.autoShowOptionalUpdate = true,
    this.enableLogging = true,
  });

  ExampleSettings copyWith({
    String? simulatedVersion,
    AppControlDisplayMode? maintenanceDisplayMode,
    AppControlDisplayMode? forceUpdateDisplayMode,
    OptionalUpdateDisplayMode? optionalUpdateDisplayMode,
    bool? useCustomBuilders,
    bool? autoShowOptionalUpdate,
    bool? enableLogging,
  }) {
    return ExampleSettings(
      simulatedVersion: simulatedVersion ?? this.simulatedVersion,
      maintenanceDisplayMode:
          maintenanceDisplayMode ?? this.maintenanceDisplayMode,
      forceUpdateDisplayMode:
          forceUpdateDisplayMode ?? this.forceUpdateDisplayMode,
      optionalUpdateDisplayMode:
          optionalUpdateDisplayMode ?? this.optionalUpdateDisplayMode,
      useCustomBuilders: useCustomBuilders ?? this.useCustomBuilders,
      autoShowOptionalUpdate:
          autoShowOptionalUpdate ?? this.autoShowOptionalUpdate,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}

/// InheritedWidget to provide settings and log callbacks down the widget tree.
class ExampleSettingsScope extends InheritedWidget {
  final ExampleSettings settings;
  final ValueChanged<ExampleSettings> onUpdateSettings;
  final List<String> logs;
  final VoidCallback onClearLogs;

  const ExampleSettingsScope({
    super.key,
    required this.settings,
    required this.onUpdateSettings,
    required this.logs,
    required this.onClearLogs,
    required super.child,
  });

  static ExampleSettingsScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExampleSettingsScope>();
    assert(scope != null, 'No ExampleSettingsScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ExampleSettingsScope oldWidget) {
    return settings != oldWidget.settings ||
        logs.length != oldWidget.logs.length;
  }
}

/// Root widget managing reactive settings and wrapping [FirestoreAppControl].
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ExampleSettings _settings = const ExampleSettings();
  final List<String> _logs = [];

  bool _logUpdateScheduled = false;

  void _addLog(
    String message, {
    AppControlLogLevel level = AppControlLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(
      0,
      '[$time][${level.label}] $message'
      '${error != null ? ' | error: $error' : ''}',
    );
    if (_logs.length > 200) _logs.removeLast();

    if (!_logUpdateScheduled) {
      _logUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logUpdateScheduled = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  void _updateSettings(ExampleSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  @override
  Widget build(BuildContext context) {
    // Unique key triggers clean re-initialization of FirestoreAppControl when
    // version, display modes, or custom builder mode changes.
    final controlKey = ValueKey(
      '${_settings.simulatedVersion}_'
      '${_settings.maintenanceDisplayMode}_'
      '${_settings.forceUpdateDisplayMode}_'
      '${_settings.optionalUpdateDisplayMode}_'
      '${_settings.useCustomBuilders}_'
      '${_settings.autoShowOptionalUpdate}',
    );

    return ExampleSettingsScope(
      settings: _settings,
      onUpdateSettings: _updateSettings,
      logs: _logs,
      onClearLogs: _clearLogs,
      child: MaterialApp(
        title: 'Firestore App Control Showcase',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          return FirestoreAppControl(
            key: controlKey,
            documentPath: 'app_config/global',
            overrideVersion: _settings.simulatedVersion,
            maintenanceDisplayMode: _settings.maintenanceDisplayMode,
            forceUpdateDisplayMode: _settings.forceUpdateDisplayMode,
            optionalUpdateDisplayMode: _settings.optionalUpdateDisplayMode,
            autoShowOptionalUpdate: _settings.autoShowOptionalUpdate,
            enableLogging: _settings.enableLogging,
            logHandler: _addLog,
            // Custom Builders (Covering custom UI use cases)
            maintenanceBuilder:
                _settings.useCustomBuilders ? _customMaintenanceBuilder : null,
            forceUpdateBuilder:
                _settings.useCustomBuilders ? _customForceUpdateBuilder : null,
            optionalUpdateBuilder:
                _settings.useCustomBuilders ? _customOptionalUpdateBuilder : null,
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }

  // ── Custom Builders for Showcase ───────────────────────────────────────────

  Widget _customMaintenanceBuilder(
    BuildContext context,
    MaintenanceConfig maintenance,
    VoidCallback onRetry,
  ) {
    final isDialog =
        _settings.maintenanceDisplayMode == AppControlDisplayMode.dialog;

    final cardContent = Card(
      color: isDialog
          ? const Color(0xFF1A1A24)
          : Colors.black.withValues(alpha: 0.8),
      elevation: isDialog ? 24 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.amber.shade400, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 52,
                color: Colors.amberAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDialog
                  ? '✨ CUSTOM MAINTENANCE DIALOG'
                  : '✨ CUSTOM MAINTENANCE FULL-SCREEN',
              style: TextStyle(
                color: Colors.amber.shade300,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              maintenance.titleEn.isNotEmpty
                  ? maintenance.titleEn
                  : 'System Under Maintenance',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              maintenance.messageEn.isNotEmpty
                  ? maintenance.messageEn
                  : 'We are deploying performance upgrades. Please check back soon!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Reconnecting'),
            ),
          ],
        ),
      ),
    );

    if (isDialog) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: cardContent,
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.amber.shade900,
              Colors.orange.shade700,
              Colors.black87,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _customForceUpdateBuilder(
    BuildContext context,
    PlatformConfig platformConfig,
    String currentVersion,
    bool isOffline,
    VoidCallback onRetry,
  ) {
    final isDialog =
        _settings.forceUpdateDisplayMode == AppControlDisplayMode.dialog;

    final cardContent = Card(
      color: isDialog
          ? const Color(0xFF1E1417)
          : Colors.black.withValues(alpha: 0.85),
      elevation: isDialog ? 24 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.redAccent.shade200, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_security_update_rounded,
                size: 52,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDialog
                  ? '✨ CUSTOM FORCE UPDATE DIALOG'
                  : '✨ CUSTOM FORCE UPDATE FULL-SCREEN',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mandatory Upgrade Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Installed: v$currentVersion ➔ Required: v${platformConfig.minimumVersion}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Update via Store'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.sync_rounded, color: Colors.white60),
              label: const Text(
                'Check Again',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDialog) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: cardContent,
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade900,
              Colors.redAccent.shade700,
              Colors.black87,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _customOptionalUpdateBuilder(
    BuildContext context,
    PlatformConfig platformConfig,
    String currentVersion,
    VoidCallback onDismiss,
  ) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.deepPurple.shade900,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurpleAccent, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.amberAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✨ CUSTOM OPTIONAL UPDATE',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'v${platformConfig.latestVersion} Available!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current version is $currentVersion.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: onDismiss,
                    child: const Text('Get It'),
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

/// Primary Home Screen containing the interactive control dashboard and use cases.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ExampleSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore App Control'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Live Diagnostics Logs',
            icon: Badge(
              label: Text('${scope.logs.length}'),
              isLabelVisible: scope.logs.isNotEmpty,
              child: const Icon(Icons.terminal_rounded),
            ),
            onPressed: () => _showLogsSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildConnectionCard(context),
          const SizedBox(height: 16),
          _buildFirestorePresetSection(context),
          const SizedBox(height: 16),
          _buildSimulatedVersionSection(context),
          const SizedBox(height: 16),
          _buildDisplayModesSection(context),
          const SizedBox(height: 16),
          _buildNavigationAndManualTriggersSection(context),
          const SizedBox(height: 32),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogsSheet(context),
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text('Logs (${scope.logs.length})'),
      ),
    );
  }

  // ── Connection Status Card ─────────────────────────────────────────────────

  Widget _buildConnectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final scope = ExampleSettingsScope.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Connected Firebase Project',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Project: Firebase App Control (fir-app-control-ff3e2)\n'
              'Document: app_config/global\n'
              'Sync: Real-time Firestore snapshot listener',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: Text('App Version: ${scope.settings.simulatedVersion}'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: Icon(
                    scope.settings.useCustomBuilders
                        ? Icons.palette_outlined
                        : Icons.layers_outlined,
                    size: 16,
                  ),
                  label: Text(
                    scope.settings.useCustomBuilders
                        ? 'Custom UI'
                        : 'Default UI',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Preset Writer Section (Firestore Admin Simulator) ──────────────────────

  Widget _buildFirestorePresetSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Live Firestore Remote Presets',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Writes directly to Firestore document "app_config/global". '
              'The package will react instantly via real-time stream.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetButton(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  label: '🟢 Normal Mode',
                  onPressed: () => _writePresetToFirestore(
                    context,
                    label: 'Normal Operation',
                    data: {
                      'maintenance': {
                        'enabled': false,
                        'title_en': '',
                        'message_en': '',
                        'title_ar': '',
                        'message_ar': '',
                      },
                      'android': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.0.0',
                        'store_url': 'https://play.google.com',
                      },
                      'ios': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.0.0',
                        'store_url': 'https://apps.apple.com',
                      },
                    },
                  ),
                ),
                _PresetButton(
                  icon: Icons.build_circle_outlined,
                  color: Colors.amber.shade800,
                  label: '🟡 Maintenance Mode',
                  onPressed: () => _writePresetToFirestore(
                    context,
                    label: 'Maintenance Mode',
                    data: {
                      'maintenance': {
                        'enabled': true,
                        'title_en': 'Emergency Maintenance',
                        'message_en':
                            'Our servers are currently undergoing planned maintenance.',
                        'title_ar': 'صيانة مجدولة',
                        'message_ar': 'خوادمنا تخضع للصيانة الدورية.',
                      },
                      'android': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.0.0',
                        'store_url': 'https://play.google.com',
                      },
                      'ios': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.0.0',
                        'store_url': 'https://apps.apple.com',
                      },
                    },
                  ),
                ),
                _PresetButton(
                  icon: Icons.system_security_update_rounded,
                  color: Colors.red.shade700,
                  label: '🔴 Force Update (v2.0.0)',
                  onPressed: () => _writePresetToFirestore(
                    context,
                    label: 'Force Update',
                    data: {
                      'maintenance': {'enabled': false},
                      'android': {
                        'minimum_version': '2.0.0',
                        'latest_version': '2.0.0',
                        'store_url': 'https://play.google.com',
                      },
                      'ios': {
                        'minimum_version': '2.0.0',
                        'latest_version': '2.0.0',
                        'store_url': 'https://apps.apple.com',
                      },
                    },
                  ),
                ),
                _PresetButton(
                  icon: Icons.notification_important_outlined,
                  color: Colors.blue.shade700,
                  label: '🔵 Optional Update (v1.5.0)',
                  onPressed: () => _writePresetToFirestore(
                    context,
                    label: 'Optional Update',
                    data: {
                      'maintenance': {'enabled': false},
                      'android': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.5.0',
                        'store_url': 'https://play.google.com',
                      },
                      'ios': {
                        'minimum_version': '1.0.0',
                        'latest_version': '1.5.0',
                        'store_url': 'https://apps.apple.com',
                      },
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _writePresetToFirestore(
    BuildContext context, {
    required String label,
    required Map<String, dynamic> data,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Pushing "$label" to Firestore...'),
          duration: const Duration(seconds: 1),
        ),
      );

      await FirebaseFirestore.instance
          .doc('app_config/global')
          .set(data, SetOptions(merge: true));

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text('Successfully wrote "$label" to app_config/global!'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text('Firestore write failed: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Simulated App Version Selector ─────────────────────────────────────────

  Widget _buildSimulatedVersionSection(BuildContext context) {
    final scope = ExampleSettingsScope.of(context);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Simulated App Version',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Change the version perceived by the package to test '
              'how version comparisons behave locally.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: '1.0.0',
                  label: Text('1.0.0 (Legacy)'),
                  icon: Icon(Icons.history_rounded),
                ),
                ButtonSegment(
                  value: '1.5.0',
                  label: Text('1.5.0 (Mid)'),
                  icon: Icon(Icons.trending_up_rounded),
                ),
                ButtonSegment(
                  value: '2.0.0',
                  label: Text('2.0.0 (Latest)'),
                  icon: Icon(Icons.verified_rounded),
                ),
              ],
              selected: {scope.settings.simulatedVersion},
              onSelectionChanged: (set) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(simulatedVersion: set.first),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Display Mode & Builder Settings ────────────────────────────────────────

  Widget _buildDisplayModesSection(BuildContext context) {
    final scope = ExampleSettingsScope.of(context);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Display Modes & Custom Builders',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use Custom Branded Builders'),
              subtitle: const Text(
                'Demonstrates custom maintenanceBuilder, forceUpdateBuilder, and optionalUpdateBuilder.',
              ),
              value: scope.settings.useCustomBuilders,
              onChanged: (val) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(useCustomBuilders: val),
                );
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Maintenance Display Mode',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<AppControlDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: AppControlDisplayMode.fullScreen,
                  label: Text('Full-Screen'),
                  icon: Icon(Icons.fullscreen_rounded),
                ),
                ButtonSegment(
                  value: AppControlDisplayMode.dialog,
                  label: Text('Dialog Modal'),
                  icon: Icon(Icons.picture_in_picture_rounded),
                ),
              ],
              selected: {scope.settings.maintenanceDisplayMode},
              onSelectionChanged: (set) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(maintenanceDisplayMode: set.first),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Force Update Display Mode',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<AppControlDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: AppControlDisplayMode.fullScreen,
                  label: Text('Full-Screen'),
                  icon: Icon(Icons.fullscreen_rounded),
                ),
                ButtonSegment(
                  value: AppControlDisplayMode.dialog,
                  label: Text('Dialog Modal'),
                  icon: Icon(Icons.picture_in_picture_rounded),
                ),
              ],
              selected: {scope.settings.forceUpdateDisplayMode},
              onSelectionChanged: (set) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(forceUpdateDisplayMode: set.first),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Optional Update Display Mode',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<OptionalUpdateDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: OptionalUpdateDisplayMode.dialog,
                  label: Text('Dialog'),
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                ButtonSegment(
                  value: OptionalUpdateDisplayMode.snackBar,
                  label: Text('SnackBar'),
                  icon: Icon(Icons.call_to_action_rounded),
                ),
                ButtonSegment(
                  value: OptionalUpdateDisplayMode.fullScreen,
                  label: Text('Full-Screen'),
                  icon: Icon(Icons.open_in_full_rounded),
                ),
              ],
              selected: {scope.settings.optionalUpdateDisplayMode},
              onSelectionChanged: (set) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(optionalUpdateDisplayMode: set.first),
                );
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Show Optional Update'),
              subtitle: const Text(
                'When false, updates only trigger when calling showOptionalUpdateDialog manually.',
              ),
              value: scope.settings.autoShowOptionalUpdate,
              onChanged: (val) {
                scope.onUpdateSettings(
                  scope.settings.copyWith(autoShowOptionalUpdate: val),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation & Manual Trigger Demos ──────────────────────────────────────

  Widget _buildNavigationAndManualTriggersSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Navigation & Manual Triggers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.touch_app_rounded)),
              title: const Text('Manual Update Check Trigger'),
              subtitle: const Text(
                'Calls FirestoreAppControl.showOptionalUpdateDialog(context).',
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  FirestoreAppControl.showOptionalUpdateDialog(context);
                },
                child: const Text('Trigger'),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.alt_route_rounded)),
              title: const Text('Overlay Route Persistence Test'),
              subtitle: const Text(
                'Navigate to a sub-route; verifies overlays survive page transitions.',
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DetailScreen(),
                    ),
                  );
                },
                child: const Text('Navigate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Logs Sheet ────────────────────────────────────────────────────────

  void _showLogsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final scope = ExampleSettingsScope.of(sheetContext);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.terminal_rounded,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Diagnostic Logs (${scope.logs.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Clear Logs',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white60,
                        ),
                        onPressed: scope.onClearLogs,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: scope.logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No logs captured yet.\nInteract with the app or Firebase to see events.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: scope.logs.length,
                            itemBuilder: (context, index) {
                              final log = scope.logs[index];
                              Color textColor = Colors.white70;
                              if (log.contains('ERROR')) {
                                textColor = Colors.redAccent;
                              } else if (log.contains('WARNING')) {
                                textColor = Colors.amberAccent;
                              } else if (log.contains('Maintenance')) {
                                textColor = Colors.orangeAccent;
                              } else if (log.contains('Update')) {
                                textColor = Colors.lightBlueAccent;
                              }

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Simple sub-page demonstrating that modal/in-stack overlays persist across routes.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sub Page (Route Persistence)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'You navigated to DetailScreen!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'If an update or maintenance event occurs, the blocking overlay '
                'will continue to protect the app irrespective of navigation state.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _PresetButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
