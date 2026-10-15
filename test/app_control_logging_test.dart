import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firestore_app_control/firestore_app_control.dart';

class MockLogEntry {
  final String message;
  final AppControlLogLevel level;
  final Object? error;
  final StackTrace? stackTrace;

  MockLogEntry({
    required this.message,
    required this.level,
    this.error,
    this.stackTrace,
  });
}

class FakeLoggingDataSource implements FirestoreConfigDataSource {
  final StreamController<AppConfig> _controller =
      StreamController<AppConfig>.broadcast();
  AppConfig current = AppConfig.fromMap(null);

  void emit(AppConfig config) {
    current = config;
    _controller.add(config);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<AppConfig> watchConfig() => _controller.stream;

  @override
  Future<AppConfig> fetchConfig() async => current;

  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLoggingDataSource fakeDataSource;
  late List<MockLogEntry> logs;

  void testLogHandler(
    String message, {
    AppControlLogLevel level = AppControlLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    logs.add(MockLogEntry(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  setUp(() {
    fakeDataSource = FakeLoggingDataSource();
    logs = [];
    AppControlLogger.enableLogging = false;
    AppControlLogger.customHandler = null;
  });

  tearDown(() {
    fakeDataSource.dispose();
    AppControlLogger.enableLogging = false;
    AppControlLogger.customHandler = null;
  });

  group('AppControlLogger Unit Tests', () {
    test('AppControlLogger does not emit logs when enableLogging is false', () {
      AppControlLogger.enableLogging = false;
      AppControlLogger.customHandler = testLogHandler;

      AppControlLogger.info('Should not be recorded');
      AppControlLogger.warning('Should not be recorded');
      AppControlLogger.error('Should not be recorded');
      AppControlLogger.debug('Should not be recorded');

      expect(logs, isEmpty);
    });

    test('AppControlLogger forwards logs to customHandler when enableLogging is true', () {
      AppControlLogger.enableLogging = true;
      AppControlLogger.customHandler = testLogHandler;

      AppControlLogger.debug('Debug msg');
      AppControlLogger.info('Info msg');
      AppControlLogger.warning('Warn msg');
      AppControlLogger.error('Error msg', error: 'SampleError');

      expect(logs.length, equals(4));
      expect(logs[0].level, equals(AppControlLogLevel.debug));
      expect(logs[0].message, equals('Debug msg'));
      expect(logs[1].level, equals(AppControlLogLevel.info));
      expect(logs[1].message, equals('Info msg'));
      expect(logs[2].level, equals(AppControlLogLevel.warning));
      expect(logs[2].message, equals('Warn msg'));
      expect(logs[3].level, equals(AppControlLogLevel.error));
      expect(logs[3].message, equals('Error msg'));
      expect(logs[3].error, equals('SampleError'));
    });

    test('AppControlLogContext respects local toggle and local handler over global settings', () {
      AppControlLogger.enableLogging = false; // globally disabled

      final contextLogs = <MockLogEntry>[];
      final context = AppControlLogContext(
        enableLogging: true, // locally enabled
        logHandler: (message, {level = AppControlLogLevel.info, error, stackTrace}) {
          contextLogs.add(MockLogEntry(message: message, level: level, error: error));
        },
      );

      context.info('Scoped message');
      expect(contextLogs.length, equals(1));
      expect(contextLogs.first.message, equals('Scoped message'));
      expect(logs, isEmpty); // Global logs remained empty
    });
  });

  group('AppControlCubit Diagnostic Logging Tests', () {
    test('AppControlCubit emits diagnostic logs across initialization and state changes', () async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.2.0',
        overrideIsAndroid: true,
        overrideIsIOS: false,
        enableLogging: true,
        logHandler: testLogHandler,
      );

      await cubit.init();

      // Check initialization logs
      expect(
        logs.any((l) => l.message.contains('AppControlCubit instantiated.')),
        isTrue,
      );
      expect(
        logs.any((l) => l.message.contains('Initializing AppControlCubit...')),
        isTrue,
      );
      expect(
        logs.any((l) => l.message.contains('Using override app version: "1.2.0"')),
        isTrue,
      );

      // Normal state evaluation
      fakeDataSource.emit(AppConfig(
        maintenance: const MaintenanceConfig(
          enabled: false,
          titleAr: '',
          titleEn: '',
          messageAr: '',
          messageEn: '',
        ),
        android: const PlatformConfig(
          minimumVersion: '1.0.0',
          latestVersion: '1.2.0',
          storeUrl: 'https://store',
        ),
        ios: const PlatformConfig(
          minimumVersion: '1.0.0',
          latestVersion: '1.2.0',
          storeUrl: 'https://store',
        ),
      ));
      await pumpEventQueue();

      expect(
        logs.any((l) => l.message.contains('Application is up to date')),
        isTrue,
      );

      // Force update state evaluation
      fakeDataSource.emit(AppConfig(
        maintenance: const MaintenanceConfig(
          enabled: false,
          titleAr: '',
          titleEn: '',
          messageAr: '',
          messageEn: '',
        ),
        android: const PlatformConfig(
          minimumVersion: '2.0.0',
          latestVersion: '2.0.0',
          storeUrl: 'https://store',
        ),
        ios: const PlatformConfig(
          minimumVersion: '2.0.0',
          latestVersion: '2.0.0',
          storeUrl: 'https://store',
        ),
      ));
      await pumpEventQueue();

      expect(
        logs.any((l) => l.message.contains('Force update required') && l.level == AppControlLogLevel.warning),
        isTrue,
      );

      // Maintenance state evaluation
      fakeDataSource.emit(AppConfig(
        maintenance: const MaintenanceConfig(
          enabled: true,
          titleAr: '',
          titleEn: 'Scheduled',
          messageAr: '',
          messageEn: '',
        ),
        android: const PlatformConfig(
          minimumVersion: '1.0.0',
          latestVersion: '1.0.0',
          storeUrl: 'https://store',
        ),
        ios: const PlatformConfig(
          minimumVersion: '1.0.0',
          latestVersion: '1.0.0',
          storeUrl: 'https://store',
        ),
      ));
      await pumpEventQueue();

      expect(
        logs.any((l) => l.message.contains('Maintenance mode is active.') && l.level == AppControlLogLevel.warning),
        isTrue,
      );

      await cubit.close();
      expect(
        logs.any((l) => l.message.contains('Closing AppControlCubit')),
        isTrue,
      );
    });

    test('AppControlCubit logs error when stream fails', () async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
        enableLogging: true,
        logHandler: testLogHandler,
      );

      await cubit.init();
      fakeDataSource.emitError(Exception('Firebase network timeout'));
      await pumpEventQueue();

      expect(
        logs.any((l) => l.message.contains('Error in AppControlCubit') && l.level == AppControlLogLevel.error),
        isTrue,
      );

      await cubit.close();
    });
  });

  group('FirestoreAppControl Widget Logging Integration Tests', () {
    testWidgets('FirestoreAppControl logs lifecycle and overlay actions', (tester) async {
      final widgetLogs = <MockLogEntry>[];
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
        enableLogging: true,
        logHandler: (msg, {level = AppControlLogLevel.info, error, stackTrace}) {
          widgetLogs.add(MockLogEntry(message: msg, level: level, error: error));
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FirestoreAppControl(
            cubit: cubit,
            enableLogging: true,
            logHandler: (msg, {level = AppControlLogLevel.info, error, stackTrace}) {
              widgetLogs.add(MockLogEntry(message: msg, level: level, error: error));
            },
            child: const Scaffold(body: Text('Content')),
          ),
        ),
      );

      expect(
        widgetLogs.any((l) => l.message.contains('FirestoreAppControl initialized.')),
        isTrue,
      );

      await cubit.close();
    });
  });
}
