import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firestore_app_control/firestore_app_control.dart';

class FakeConfigDataSource implements FirestoreConfigDataSource {
  final StreamController<AppConfig> _controller = StreamController<AppConfig>.broadcast();
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

  late FakeConfigDataSource fakeDataSource;

  setUp(() {
    fakeDataSource = FakeConfigDataSource();
  });

  tearDown(() {
    fakeDataSource.dispose();
  });

  AppConfig makeConfig({
    bool maintenance = false,
    String minVersion = '1.0.0',
    String latestVersion = '1.0.0',
  }) {
    return AppConfig(
      maintenance: MaintenanceConfig(
        enabled: maintenance,
        titleAr: 'صيانة تجريبية',
        titleEn: 'Test Maintenance',
        messageAr: 'رسالة',
        messageEn: 'Message',
      ),
      android: PlatformConfig(
        minimumVersion: minVersion,
        latestVersion: latestVersion,
        storeUrl: 'https://android.store',
      ),
      ios: PlatformConfig(
        minimumVersion: minVersion,
        latestVersion: latestVersion,
        storeUrl: 'https://ios.store',
      ),
    );
  }

  group('FirestoreAppControl Package Tests', () {
    test('AppVersion parses and compares semantic versions correctly', () {
      expect(AppVersion.parse('1.10.0') > AppVersion.parse('1.9.0'), isTrue);
      expect(AppVersion.parse('2.0.0') > AppVersion.parse('1.9.9'), isTrue);
      expect(AppVersion.parse('1.0.0') == AppVersion.parse('1.0.0'), isTrue);
      expect(AppVersion.parse('1.2') == AppVersion.parse('1.2.0'), isTrue);
      expect(AppVersion.parse('1.0.0-beta') < AppVersion.parse('1.0.0'), isTrue);
    });

    test('AppControlCubit switches between states in realtime', () async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.5.0',
        overrideIsAndroid: true,
        overrideIsIOS: false,
      );

      final states = <AppControlState>[];
      cubit.stream.listen(states.add);

      await cubit.init();

      // Normal state
      fakeDataSource.emit(makeConfig(minVersion: '1.0.0', latestVersion: '1.5.0'));
      await pumpEventQueue();
      expect(states.last, isA<AppControlNormal>());

      // Maintenance state
      fakeDataSource.emit(makeConfig(maintenance: true));
      await pumpEventQueue();
      expect(states.last, isA<AppControlMaintenance>());

      // Force Update state
      fakeDataSource.emit(makeConfig(minVersion: '2.0.0'));
      await pumpEventQueue();
      expect(states.last, isA<AppControlForceUpdate>());

      // Optional Update state
      fakeDataSource.emit(makeConfig(minVersion: '1.0.0', latestVersion: '2.0.0'));
      await pumpEventQueue();
      expect(states.last, isA<AppControlOptionalUpdate>());

      // Session dismissal
      cubit.dismissOptionalUpdateForSession();
      await pumpEventQueue();
      expect(states.last, isA<AppControlNormal>());

      await cubit.close();
    });

    testWidgets('FirestoreAppControl widget displays custom maintenance view when active',
        (tester) async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FirestoreAppControl(
            cubit: cubit,
            maintenanceBuilder: (context, m, onRetry) =>
                const Scaffold(body: Center(child: Text('Custom Maintenance Active'))),
            child: const Scaffold(body: Center(child: Text('Normal App Body'))),
          ),
        ),
      );

      await cubit.init();

      // Start with normal
      fakeDataSource.emit(makeConfig(maintenance: false));
      await tester.pumpAndSettle();
      expect(find.text('Normal App Body'), findsOneWidget);

      // Trigger maintenance
      fakeDataSource.emit(makeConfig(maintenance: true));
      await tester.pumpAndSettle();
      expect(find.text('Custom Maintenance Active'), findsOneWidget);
      expect(find.text('Normal App Body'), findsNothing);

      await cubit.close();
    });

    testWidgets('FirestoreAppControl shows optional update dialog when home is used',
        (tester) async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FirestoreAppControl(
            cubit: cubit,
            child: const Scaffold(body: Center(child: Text('Normal App Body'))),
          ),
        ),
      );

      await cubit.init();

      // Trigger Optional Update
      fakeDataSource.emit(makeConfig(minVersion: '1.0.0', latestVersion: '2.0.0'));
      await tester.pumpAndSettle();

      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.text('Normal App Body'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('FirestoreAppControl shows optional update dialog when used in MaterialApp.builder',
        (tester) async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FirestoreAppControl(
            cubit: cubit,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('Normal App Body'))),
        ),
      );

      await cubit.init();

      // Trigger Optional Update
      fakeDataSource.emit(makeConfig(minVersion: '1.0.0', latestVersion: '2.0.0'));
      await tester.pumpAndSettle();

      expect(find.text('New Version Available'), findsOneWidget);

      await cubit.close();
    });

    testWidgets(
        'Optional update overlay survives pushReplacement from SplashPage without disappearing',
        (tester) async {
      final cubit = AppControlCubit(
        dataSource: fakeDataSource,
        overrideVersion: '1.0.0',
      );

      late BuildContext splashContext;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FirestoreAppControl(
            cubit: cubit,
            child: child!,
          ),
          home: Builder(
            builder: (ctx) {
              splashContext = ctx;
              return const Scaffold(body: Center(child: Text('Splash Screen Logo')));
            },
          ),
        ),
      );

      await cubit.init();

      // Trigger Optional Update while on Splash
      fakeDataSource.emit(makeConfig(minVersion: '1.0.0', latestVersion: '2.0.0'));
      await tester.pumpAndSettle();

      // Assert dialog appeared over Splash
      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.text('Splash Screen Logo'), findsOneWidget);

      // Now Splash completes and calls pushReplacement to Main Navigation Page!
      Navigator.of(splashContext).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Main Navigation Page'))),
        ),
      );
      await tester.pumpAndSettle();

      // THE CRITICAL TEST:
      // Dialog MUST STILL BE VISIBLE! It did NOT disappear!
      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.text('Main Navigation Page'), findsOneWidget);
      expect(find.text('Splash Screen Logo'), findsNothing);

      // Dismiss dialog
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Dialog is gone, Main Navigation Page remains!
      expect(find.text('New Version Available'), findsNothing);
      expect(find.text('Main Navigation Page'), findsOneWidget);

      await cubit.close();
    });
  });
}
