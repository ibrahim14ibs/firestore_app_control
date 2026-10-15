import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Severity levels for Firestore App Control diagnostic logs.
enum AppControlLogLevel {
  /// Detailed diagnostic information for debugging.
  debug,

  /// General operational messages highlighting normal application control events.
  info,

  /// Non-fatal warnings indicating unexpected states or fallbacks.
  warning,

  /// Failures, exceptions, and store launch errors.
  error;

  /// Uppercase text label representing the log level.
  String get label => switch (this) {
        AppControlLogLevel.debug => 'DEBUG',
        AppControlLogLevel.info => 'INFO',
        AppControlLogLevel.warning => 'WARN',
        AppControlLogLevel.error => 'ERROR',
      };
}

/// Signature for custom log handlers.
///
/// Can be used to pipe logs to custom sinks such as Crashlytics, Sentry, or custom file loggers.
typedef AppControlLogHandler = void Function(
  String message, {
  AppControlLogLevel level,
  Object? error,
  StackTrace? stackTrace,
});

/// Diagnostic logging manager for the `firestore_app_control` package.
///
/// Logging can be toggled globally via [enableLogging] or per-instance via
/// `FirestoreAppControl(enableLogging: true)` or `AppControlCubit(enableLogging: true)`.
class AppControlLogger {
  AppControlLogger._();

  /// Global master switch to enable or disable diagnostic logging across the entire package.
  ///
  /// Defaults to `false`.
  static bool enableLogging = false;

  /// Global custom log handler callback.
  ///
  /// When provided, logs are forwarded to this handler instead of the default console logger.
  static AppControlLogHandler? customHandler;

  /// Default console log handler using [developer.log] and [debugPrint].
  static void defaultHandler(
    String message, {
    AppControlLogLevel level = AppControlLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formattedMessage = '[FirestoreAppControl][${level.label}] $message';

    developer.log(
      message,
      name: 'FirestoreAppControl',
      level: switch (level) {
        AppControlLogLevel.debug => 500,
        AppControlLogLevel.info => 800,
        AppControlLogLevel.warning => 900,
        AppControlLogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );

    debugPrint(formattedMessage);
    if (error != null) {
      debugPrint('[FirestoreAppControl][${level.label}] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[FirestoreAppControl][${level.label}] StackTrace: $stackTrace');
    }
  }

  /// Dispatches a log message if logging is enabled.
  static void log(
    String message, {
    AppControlLogLevel level = AppControlLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    bool? isEnabled,
    AppControlLogHandler? handler,
  }) {
    final active = isEnabled ?? enableLogging;
    if (!active) return;

    final targetHandler = handler ?? customHandler ?? defaultHandler;
    targetHandler(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a debug level message.
  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool? isEnabled,
    AppControlLogHandler? handler,
  }) {
    log(
      message,
      level: AppControlLogLevel.debug,
      error: error,
      stackTrace: stackTrace,
      isEnabled: isEnabled,
      handler: handler,
    );
  }

  /// Logs an info level message.
  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool? isEnabled,
    AppControlLogHandler? handler,
  }) {
    log(
      message,
      level: AppControlLogLevel.info,
      error: error,
      stackTrace: stackTrace,
      isEnabled: isEnabled,
      handler: handler,
    );
  }

  /// Logs a warning level message.
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool? isEnabled,
    AppControlLogHandler? handler,
  }) {
    log(
      message,
      level: AppControlLogLevel.warning,
      error: error,
      stackTrace: stackTrace,
      isEnabled: isEnabled,
      handler: handler,
    );
  }

  /// Logs an error level message.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool? isEnabled,
    AppControlLogHandler? handler,
  }) {
    log(
      message,
      level: AppControlLogLevel.error,
      error: error,
      stackTrace: stackTrace,
      isEnabled: isEnabled,
      handler: handler,
    );
  }
}

/// Scoped logging context helper for instances with optional local toggles or custom handlers.
class AppControlLogContext {
  /// Local toggle for logging. If `null`, falls back to [AppControlLogger.enableLogging].
  final bool? enableLogging;

  /// Local custom log handler. If `null`, falls back to [AppControlLogger.customHandler].
  final AppControlLogHandler? logHandler;

  const AppControlLogContext({
    this.enableLogging,
    this.logHandler,
  });

  /// Logs a debug message within this context.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    AppControlLogger.debug(
      message,
      error: error,
      stackTrace: stackTrace,
      isEnabled: enableLogging,
      handler: logHandler,
    );
  }

  /// Logs an info message within this context.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    AppControlLogger.info(
      message,
      error: error,
      stackTrace: stackTrace,
      isEnabled: enableLogging,
      handler: logHandler,
    );
  }

  /// Logs a warning message within this context.
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    AppControlLogger.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      isEnabled: enableLogging,
      handler: logHandler,
    );
  }

  /// Logs an error message within this context.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    AppControlLogger.error(
      message,
      error: error,
      stackTrace: stackTrace,
      isEnabled: enableLogging,
      handler: logHandler,
    );
  }
}
