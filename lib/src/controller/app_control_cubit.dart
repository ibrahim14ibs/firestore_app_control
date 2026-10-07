import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/firestore_config_data_source.dart';
import '../models/app_config.dart';
import '../utils/app_version.dart';
import 'app_control_state.dart';

class AppControlCubit extends Cubit<AppControlState> with WidgetsBindingObserver {
  final FirestoreConfigDataSource _dataSource;
  final String? _overrideVersion;
  final bool? _overrideIsAndroid;
  final bool? _overrideIsIOS;

  StreamSubscription? _subscription;
  bool _optionalUpdateDismissedInSession = false;
  AppConfig? _lastValidConfig;
  String _currentVersion = '1.0.0';

  AppControlCubit({
    required FirestoreConfigDataSource dataSource,
    String? overrideVersion,
    bool? overrideIsAndroid,
    bool? overrideIsIOS,
  })  : _dataSource = dataSource,
        _overrideVersion = overrideVersion,
        _overrideIsAndroid = overrideIsAndroid,
        _overrideIsIOS = overrideIsIOS,
        super(const AppControlInitial()) {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _isAndroid => _overrideIsAndroid ?? (!kIsWeb && Platform.isAndroid);
  bool get _isIOS => _overrideIsIOS ?? (!kIsWeb && Platform.isIOS);

  Future<void> init() async {
    if (_subscription != null) return;

    emit(const AppControlLoading());

    if (_overrideVersion != null) {
      _currentVersion = _overrideVersion;
    } else {
      try {
        final info = await PackageInfo.fromPlatform();
        _currentVersion = info.version;
      } catch (_) {
        _currentVersion = '1.0.0';
      }
    }

    _subscription = _dataSource.watchConfig().listen(
      (config) {
        _lastValidConfig = config;
        _evaluateState(config);
      },
      onError: (error) {
        _handleError(error.toString());
      },
    );
  }

  void _evaluateState(AppConfig config) {
    // 1. Maintenance Mode
    if (config.maintenance.enabled) {
      emit(AppControlMaintenance(config.maintenance));
      return;
    }

    final platformConfig = config.platformConfigFor(
      isAndroid: _isAndroid,
      isIOS: _isIOS,
    );

    final current = AppVersion.parse(_currentVersion);
    final minimum = AppVersion.parse(platformConfig.minimumVersion);
    final latest = AppVersion.parse(platformConfig.latestVersion);

    // 2. Force Update
    if (current < minimum) {
      emit(AppControlForceUpdate(
        platformConfig: platformConfig,
        currentVersion: _currentVersion,
        isOffline: false,
      ));
      return;
    }

    // 3. Optional Update
    if (current < latest) {
      if (_optionalUpdateDismissedInSession) {
        emit(AppControlNormal(config));
      } else {
        emit(AppControlOptionalUpdate(
          platformConfig: platformConfig,
          currentVersion: _currentVersion,
          dismissedInSession: false,
        ));
      }
      return;
    }

    // 4. Normal
    emit(AppControlNormal(config));
  }

  void _handleError(String message) {
    if (_lastValidConfig != null) {
      _evaluateState(_lastValidConfig!);
    } else {
      final safeDefaults = AppConfig.safeDefaults(currentVersion: _currentVersion);
      emit(AppControlNormal(safeDefaults));
    }
  }

  void dismissOptionalUpdateForSession() {
    _optionalUpdateDismissedInSession = true;
    if (_lastValidConfig != null) {
      emit(AppControlNormal(_lastValidConfig!));
    } else {
      emit(AppControlNormal(AppConfig.safeDefaults(currentVersion: _currentVersion)));
    }
  }

  Future<void> checkConfig() async {
    final config = await _dataSource.fetchConfig();
    _lastValidConfig = config;
    _evaluateState(config);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lastValidConfig != null) {
        _evaluateState(_lastValidConfig!);
      } else {
        checkConfig();
      }
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
