import 'package:equatable/equatable.dart';

/// Configuration for Maintenance Mode.
class MaintenanceConfig extends Equatable {
  final bool enabled;
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;

  const MaintenanceConfig({
    required this.enabled,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
  });

  const MaintenanceConfig.disabled()
      : enabled = false,
        titleAr = '',
        titleEn = '',
        messageAr = '',
        messageEn = '';

  factory MaintenanceConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MaintenanceConfig.disabled();

    return MaintenanceConfig(
      enabled: _parseBool(map['enabled']),
      titleAr: _parseString(map['title_ar']),
      titleEn: _parseString(map['title_en']),
      messageAr: _parseString(map['message_ar']),
      messageEn: _parseString(map['message_en']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'title_ar': titleAr,
      'title_en': titleEn,
      'message_ar': messageAr,
      'message_en': messageEn,
    };
  }

  @override
  List<Object?> get props => [
        enabled,
        titleAr,
        titleEn,
        messageAr,
        messageEn,
      ];
}

/// Configuration for a specific mobile platform (Android or iOS).
class PlatformConfig extends Equatable {
  final String minimumVersion;
  final String latestVersion;
  final String storeUrl;

  const PlatformConfig({
    required this.minimumVersion,
    required this.latestVersion,
    required this.storeUrl,
  });

  const PlatformConfig.defaults({required String version})
      : minimumVersion = version,
        latestVersion = version,
        storeUrl = '';

  factory PlatformConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PlatformConfig(
        minimumVersion: '1.0.0',
        latestVersion: '1.0.0',
        storeUrl: '',
      );
    }

    return PlatformConfig(
      minimumVersion: _parseVersion(map['minimum_version'], defaultVer: '1.0.0'),
      latestVersion: _parseVersion(map['latest_version'], defaultVer: '1.0.0'),
      storeUrl: _parseString(map['store_url']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minimum_version': minimumVersion,
      'latest_version': latestVersion,
      'store_url': storeUrl,
    };
  }

  @override
  List<Object?> get props => [minimumVersion, latestVersion, storeUrl];
}

/// Full application remote configuration model.
class AppConfig extends Equatable {
  final MaintenanceConfig maintenance;
  final PlatformConfig android;
  final PlatformConfig ios;

  const AppConfig({
    required this.maintenance,
    required this.android,
    required this.ios,
  });

  factory AppConfig.safeDefaults({required String currentVersion}) {
    return AppConfig(
      maintenance: const MaintenanceConfig.disabled(),
      android: PlatformConfig.defaults(version: currentVersion),
      ios: PlatformConfig.defaults(version: currentVersion),
    );
  }

  factory AppConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AppConfig(
        maintenance: MaintenanceConfig.disabled(),
        android: PlatformConfig(minimumVersion: '1.0.0', latestVersion: '1.0.0', storeUrl: ''),
        ios: PlatformConfig(minimumVersion: '1.0.0', latestVersion: '1.0.0', storeUrl: ''),
      );
    }

    return AppConfig(
      maintenance: MaintenanceConfig.fromMap(_asMap(map['maintenance'])),
      android: PlatformConfig.fromMap(_asMap(map['android'])),
      ios: PlatformConfig.fromMap(_asMap(map['ios'])),
    );
  }

  PlatformConfig platformConfigFor({
    required bool isAndroid,
    required bool isIOS,
  }) {
    if (isIOS) return ios;
    return android;
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenance': maintenance.toMap(),
      'android': android.toMap(),
      'ios': ios.toMap(),
    };
  }

  @override
  List<Object?> get props => [maintenance, android, ios];
}

// ── Private parsing helpers ──────────────────────────────────────────────────

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
  return false;
}

String _parseString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _parseVersion(dynamic value, {required String defaultVer}) {
  if (value == null) return defaultVer;
  final str = value.toString().trim();
  return str.isEmpty ? defaultVer : str;
}
