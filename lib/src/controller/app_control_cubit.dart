import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/firestore_config_data_source.dart';
import '../models/app_config.dart';
import '../utils/app_control_logger.dart';
import '../utils/app_version.dart';
import 'app_control_state.dart';

class AppControlCubit extends Cubit<AppControlState> with WidgetsBindingObserver {
  final FirestoreConfigDataSource _dataSource;
  final String? _overrideVersion;
  final bool? _overrideIsAndroid;
  final bool? _overrideIsIOS;
  final AppControlLogContext _logger;

  StreamSubscription? _subscription;
  bool _optionalUpdateDismissedInSession = false;
  AppConfig? _lastValidConfig;
  String _currentVersion = '1.0.0';

  AppControlCubit({
    required FirestoreConfigDataSource dataSource,
    String? overrideVersion,
    bool? overrideIsAndroid,
    bool? overrideIsIOS,
    bool? enableLogging,
    AppControlLogHandler? logHandler,
  })  : _dataSource = dataSource,
        _overrideVersion = overrideVersion,
        _overrideIsAndroid = overrideIsAndroid,
        _overrideIsIOS = overrideIsIOS,
        _logger = AppControlLogContext(
          enableLogging: enableLogging,
          logHandler: logHandler,
        ),
        super(const AppControlInitial()) {
    WidgetsBinding.instance.addObserver(this);
    _logger.info('AppControlCubit instantiated.');
  }

  bool get _isAndroid => _overrideIsAndroid ?? (!kIsWeb && Platform.isAndroid);
  bool get _isIOS => _overrideIsIOS ?? (!kIsWeb && Platform.isIOS);

  Future<void> init() async {
    if (_subscription != null) {
      _logger.debug('AppControlCubit already initialized. Ignoring subsequent init() call.');
      return;
    }

    _logger.info('Initializing AppControlCubit...');
    emit(const AppControlLoading());

    _logger.debug('Platform configuration: isAndroid=$_isAndroid, isIOS=$_isIOS');

    if (_overrideVersion != null) {
      _currentVersion = _overrideVersion;
      _logger.info('Using override app version: "$_currentVersion"');
    } else {
      try {
        final info = await PackageInfo.fromPlatform();
        _currentVersion = info.version;
        _logger.info('Resolved app version from platform: "$_currentVersion"');
      } catch (e, stackTrace) {
        _currentVersion = '1.0.0';
        _logger.warning(
          'Failed to retrieve PackageInfo from platform. Defaulting to "$_currentVersion".',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    _logger.info('Subscribing to Firestore configuration stream...');
    _subscription = _dataSource.watchConfig().listen(
      (config) {
        _lastValidConfig = config;
        _evaluateState(config);
      },
      onError: (error, stackTrace) {
        _handleError(error.toString(), error: error, stackTrace: stackTrace);
      },
    );
  }

  void _evaluateState(AppConfig config) {
    _logger.info('Evaluating application control state for version "$_currentVersion"...');

    // 1. Maintenance Mode
    if (config.maintenance.enabled) {
      _logger.warning('Maintenance mode is active. Emitting AppControlMaintenance.');
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

    _logger.debug(
      'Version comparison: current=$_currentVersion, '
      'minimum=${platformConfig.minimumVersion}, '
      'latest=${platformConfig.latestVersion}',
    );

    // 2. Force Update
    if (current < minimum) {
      _logger.warning(
        'Force update required (current: $_currentVersion < minimum: ${platformConfig.minimumVersion}). '
        'Emitting AppControlForceUpdate.',
      );
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
        _logger.info(
          'Optional update available (${platformConfig.latestVersion}), '
          'but already dismissed in current session. Emitting AppControlNormal.',
        );
        emit(AppControlNormal(config));
      } else {
        _logger.info(
          'Optional update available (current: $_currentVersion < latest: ${platformConfig.latestVersion}). '
          'Emitting AppControlOptionalUpdate.',
        );
        emit(AppControlOptionalUpdate(
          platformConfig: platformConfig,
          currentVersion: _currentVersion,
          dismissedInSession: false,
        ));
      }
      return;
    }

    // 4. Normal
    _logger.info('Application is up to date (current: $_currentVersion). Emitting AppControlNormal.');
    emit(AppControlNormal(config));
  }

  void _handleError(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.error(
      'Error in AppControlCubit: $message. '
      'Fallback: ${_lastValidConfig != null ? "retaining last valid config" : "using safe defaults"}.',
      error: error,
      stackTrace: stackTrace,
    );
    if (_lastValidConfig != null) {
      _evaluateState(_lastValidConfig!);
    } else {
      final safeDefaults = AppConfig.safeDefaults(currentVersion: _currentVersion);
      emit(AppControlNormal(safeDefaults));
    }
  }

  void dismissOptionalUpdateForSession() {
    _logger.info('Optional update prompt dismissed for current session.');
    _optionalUpdateDismissedInSession = true;
    if (_lastValidConfig != null) {
      emit(AppControlNormal(_lastValidConfig!));
    } else {
      emit(AppControlNormal(AppConfig.safeDefaults(currentVersion: _currentVersion)));
    }
  }

  Future<void> checkConfig() async {
    _logger.info('Manual checkConfig() invoked.');
    final config = await _dataSource.fetchConfig();
    _lastValidConfig = config;
    _evaluateState(config);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.debug('App lifecycle state changed: $state');
    if (state == AppLifecycleState.resumed) {
      _logger.info('App resumed from background. Re-evaluating configuration.');
      if (_lastValidConfig != null) {
        _evaluateState(_lastValidConfig!);
      } else {
        checkConfig();
      }
    }
  }

  @override
  Future<void> close() {
    _logger.info('Closing AppControlCubit and canceling subscriptions.');
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
