import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/app_control_cubit.dart';
import '../controller/app_control_state.dart';
import '../data/firestore_config_data_source.dart';
import '../models/app_config.dart';
import '../ui/default_force_update_dialog.dart';
import '../ui/default_force_update_view.dart';
import '../ui/default_maintenance_dialog.dart';
import '../ui/default_maintenance_view.dart';
import '../ui/default_optional_update_dialog.dart';
import '../ui/default_optional_update_snackbar.dart';
import '../ui/default_optional_update_view.dart';
import '../utils/app_control_logger.dart';

/// Display mode for blocking application states (maintenance mode and force update).
enum AppControlDisplayMode {
  /// Displays as a full-screen blocking view replacing the application view.
  fullScreen,

  /// Displays as a non-dismissible modal dialog overlaid on top of the application view.
  dialog,
}

/// Display mode for optional updates.
enum OptionalUpdateDisplayMode {
  /// Displays as a modal dialog overlaid on top of the application view.
  dialog,

  /// Displays as a floating SnackBar banner overlaid at the bottom of the screen.
  snackBar,

  /// Displays as a full-screen view with a skip/continue action.
  fullScreen,
}

typedef MaintenanceWidgetBuilder = Widget Function(
  BuildContext context,
  MaintenanceConfig maintenance,
  VoidCallback onRetry,
);

typedef ForceUpdateWidgetBuilder = Widget Function(
  BuildContext context,
  PlatformConfig platformConfig,
  String currentVersion,
  bool isOffline,
  VoidCallback onRetry,
);

typedef OptionalUpdateWidgetBuilder = Widget Function(
  BuildContext context,
  PlatformConfig platformConfig,
  String currentVersion,
  VoidCallback onDismiss,
);

/// Deprecated: Use [OptionalUpdateWidgetBuilder] instead.
@Deprecated('Use OptionalUpdateWidgetBuilder instead.')
typedef OptionalUpdateDialogBuilder = OptionalUpdateWidgetBuilder;

/// Root widget for plug-and-play remote application control.
///
/// Wraps the application to provide real-time maintenance mode blocking,
/// forced updates, and root stack overlay optional update dialogs powered by
/// Firebase Firestore.
class FirestoreAppControl extends StatefulWidget {
  /// The primary application widget tree.
  ///
  /// Displayed during normal application operation and underneath the optional
  /// update overlay.
  final Widget child;

  /// The Firestore document path where configuration is stored.
  ///
  /// Defaults to `'app_config/global'`.
  final String documentPath;

  /// Custom [FirebaseFirestore] instance to use.
  ///
  /// If `null`, [FirebaseFirestore.instance] is used.
  final FirebaseFirestore? firestore;

  /// Primary theme color applied to default maintenance and update screens.
  ///
  /// If `null`, falls back to `Theme.of(context).colorScheme.primary`.
  final Color? primaryColor;

  /// Custom widget builder for maintenance mode.
  ///
  /// If provided, completely replaces the default maintenance screen.
  final MaintenanceWidgetBuilder? maintenanceBuilder;

  /// Custom widget builder for force update mode.
  ///
  /// If provided, completely replaces the default force update screen.
  final ForceUpdateWidgetBuilder? forceUpdateBuilder;

  /// Custom widget builder for optional updates.
  ///
  /// If provided, replaces the default optional update UI and is rendered
  /// according to [optionalUpdateDisplayMode].
  final OptionalUpdateWidgetBuilder? optionalUpdateBuilder;

  /// Optional pre-configured [AppControlCubit] instance.
  ///
  /// Useful for dependency injection (e.g. `get_it`) or unit testing with mocks.
  final AppControlCubit? cubit;

  /// Navigator key used when an external navigator reference is required.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Overrides the detected app version for testing purposes.
  ///
  /// When set, bypasses `PackageInfo.fromPlatform()`.
  final String? overrideVersion;

  /// Optional delay duration before displaying the optional update overlay.
  ///
  /// Defaults to `null` (shows immediately when detected).
  final Duration? optionalUpdateDelay;

  /// Whether to automatically display the optional update dialog when detected.
  ///
  /// Defaults to `true`. When set to `false`, call
  /// [FirestoreAppControl.showOptionalUpdateDialog] manually in your screen.
  final bool autoShowOptionalUpdate;

  /// Display mode for maintenance mode (both default and custom [maintenanceBuilder]).
  ///
  /// Defaults to [AppControlDisplayMode.fullScreen].
  final AppControlDisplayMode maintenanceDisplayMode;

  /// Display mode for force update (both default and custom [forceUpdateBuilder]).
  ///
  /// Defaults to [AppControlDisplayMode.fullScreen].
  final AppControlDisplayMode forceUpdateDisplayMode;

  /// Display mode for optional updates (both default and custom [optionalUpdateBuilder]).
  ///
  /// Defaults to [OptionalUpdateDisplayMode.dialog].
  final OptionalUpdateDisplayMode optionalUpdateDisplayMode;

  /// Whether to enable diagnostic runtime logs in the console.
  ///
  /// If `null`, falls back to [AppControlLogger.enableLogging].
  final bool? enableLogging;

  /// Optional custom log handler callback for intercepting logs (e.g. Sentry, Crashlytics).
  final AppControlLogHandler? logHandler;

  const FirestoreAppControl({
    super.key,
    required this.child,
    this.documentPath = 'app_config/global',
    this.firestore,
    this.primaryColor,
    this.maintenanceBuilder,
    this.forceUpdateBuilder,
    this.optionalUpdateBuilder,
    this.cubit,
    this.navigatorKey,
    this.overrideVersion,
    this.optionalUpdateDelay,
    this.autoShowOptionalUpdate = true,
    this.maintenanceDisplayMode = AppControlDisplayMode.fullScreen,
    this.forceUpdateDisplayMode = AppControlDisplayMode.fullScreen,
    this.optionalUpdateDisplayMode = OptionalUpdateDisplayMode.dialog,
    this.enableLogging,
    this.logHandler,
  });

  /// Manually triggers display of the optional update overlay if an update is available.
  ///
  /// Useful when [autoShowOptionalUpdate] is `false` to display the update on a
  /// specific screen (e.g. `HomePage` after splash navigation).
  static void showOptionalUpdateDialog(BuildContext context) {
    final state = context.findAncestorStateOfType<_FirestoreAppControlState>();
    if (state != null) {
      state._showOverlayManually();
    }
  }

  @override
  State<FirestoreAppControl> createState() => _FirestoreAppControlState();
}

class _FirestoreAppControlState extends State<FirestoreAppControl> {
  late final AppControlCubit _cubit;
  late final bool _internalCubit;
  late final AppControlLogContext _logger;
  bool _isOverlayVisible = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _logger = AppControlLogContext(
      enableLogging: widget.enableLogging,
      logHandler: widget.logHandler,
    );
    _logger.info('FirestoreAppControl initialized.');
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
      _internalCubit = false;
    } else {
      final dataSource = FirestoreConfigDataSourceImpl(
        firestore: widget.firestore,
        documentPath: widget.documentPath,
        enableLogging: widget.enableLogging,
        logHandler: widget.logHandler,
      );
      _cubit = AppControlCubit(
        dataSource: dataSource,
        overrideVersion: widget.overrideVersion,
        enableLogging: widget.enableLogging,
        logHandler: widget.logHandler,
      );
      _internalCubit = true;
      _cubit.init();
    }

    _checkInitialOptionalUpdate();
  }

  void _checkInitialOptionalUpdate() {
    final state = _cubit.state;
    if (state is AppControlOptionalUpdate && !state.dismissedInSession) {
      _scheduleOverlay(state);
    }
  }

  void _scheduleOverlay(AppControlOptionalUpdate state) {
    if (!widget.autoShowOptionalUpdate) {
      _logger.debug('autoShowOptionalUpdate is false. Optional update overlay will not be scheduled automatically.');
      return;
    }
    _delayTimer?.cancel();

    if (widget.optionalUpdateDelay != null &&
        widget.optionalUpdateDelay! > Duration.zero) {
      _logger.info('Scheduling optional update overlay to appear in ${widget.optionalUpdateDelay}.');
      _delayTimer = Timer(widget.optionalUpdateDelay!, () {
        if (mounted) {
          _logger.info('Delay timer elapsed. Displaying optional update overlay (${widget.optionalUpdateDisplayMode}).');
          setState(() => _isOverlayVisible = true);
        }
      });
    } else {
      _logger.info('Displaying optional update overlay immediately (${widget.optionalUpdateDisplayMode}).');
      _isOverlayVisible = true;
    }
  }

  void _dismissOverlay() {
    _logger.info('Dismissing optional update overlay.');
    _delayTimer?.cancel();
    if (mounted) {
      setState(() => _isOverlayVisible = false);
    }
    _cubit.dismissOptionalUpdateForSession();
  }

  void _showOverlayManually() {
    _logger.info('showOptionalUpdateDialog() triggered manually.');
    final state = _cubit.state;
    if (state is AppControlOptionalUpdate && !state.dismissedInSession) {
      setState(() => _isOverlayVisible = true);
    } else {
      _logger.info('Manual optional update dialog requested, but state is not AppControlOptionalUpdate: $state');
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing FirestoreAppControl widget.');
    _delayTimer?.cancel();
    if (_internalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AppControlCubit, AppControlState>(
        listenWhen: (prev, curr) =>
            curr is AppControlOptionalUpdate && !curr.dismissedInSession,
        listener: (context, state) {
          if (state is AppControlOptionalUpdate && !state.dismissedInSession) {
            _scheduleOverlay(state);
          }
        },
        builder: (context, state) {
          final showOverlay = _isOverlayVisible &&
              state is AppControlOptionalUpdate &&
              !state.dismissedInSession;

          Widget? overlayWidget;
          if (showOverlay) {
            final optionalState = state;
            final customWidget = widget.optionalUpdateBuilder != null
                ? widget.optionalUpdateBuilder!(
                    context,
                    optionalState.platformConfig,
                    optionalState.currentVersion,
                    _dismissOverlay,
                  )
                : null;

            switch (widget.optionalUpdateDisplayMode) {
              case OptionalUpdateDisplayMode.dialog:
                overlayWidget = Positioned.fill(
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) {
                        _dismissOverlay();
                      }
                    },
                    child: Material(
                      color: Colors.black54,
                      type: MaterialType.canvas,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _dismissOverlay,
                            ),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: customWidget ??
                                  DefaultOptionalUpdateDialog(
                                    platformConfig: optionalState.platformConfig,
                                    currentVersion: optionalState.currentVersion,
                                    onDismiss: _dismissOverlay,
                                    primaryColor: widget.primaryColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              case OptionalUpdateDisplayMode.snackBar:
                overlayWidget = Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: customWidget ??
                            DefaultOptionalUpdateSnackBar(
                              platformConfig: optionalState.platformConfig,
                              currentVersion: optionalState.currentVersion,
                              onDismiss: _dismissOverlay,
                              primaryColor: widget.primaryColor,
                            ),
                      ),
                    ),
                  ),
                );
              case OptionalUpdateDisplayMode.fullScreen:
                overlayWidget = Positioned.fill(
                  child: customWidget ??
                      DefaultOptionalUpdateView(
                        platformConfig: optionalState.platformConfig,
                        currentVersion: optionalState.currentVersion,
                        onDismiss: _dismissOverlay,
                        primaryColor: widget.primaryColor,
                      ),
                );
            }
          }

          final effectiveChild = Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              if (overlayWidget != null) overlayWidget,
            ],
          );

          return switch (state) {
            AppControlMaintenance(:final maintenance) => PopScope(
                canPop: false,
                child: widget.maintenanceDisplayMode == AppControlDisplayMode.dialog
                    ? Stack(
                        fit: StackFit.passthrough,
                        children: [
                          widget.child,
                          Positioned.fill(
                            child: Material(
                              color: Colors.black54,
                              type: MaterialType.canvas,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: widget.maintenanceBuilder != null
                                      ? widget.maintenanceBuilder!(
                                          context,
                                          maintenance,
                                          () => _cubit.checkConfig(),
                                        )
                                      : DefaultMaintenanceDialog(
                                          maintenance: maintenance,
                                          onRetry: () => _cubit.checkConfig(),
                                          primaryColor: widget.primaryColor,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : (widget.maintenanceBuilder != null
                        ? widget.maintenanceBuilder!(
                            context,
                            maintenance,
                            () => _cubit.checkConfig(),
                          )
                        : DefaultMaintenanceView(
                            maintenance: maintenance,
                            onRetry: () => _cubit.checkConfig(),
                            primaryColor: widget.primaryColor,
                          )),
              ),
            AppControlForceUpdate(
              :final platformConfig,
              :final currentVersion,
              :final isOffline,
            ) =>
              PopScope(
                canPop: false,
                child: widget.forceUpdateDisplayMode == AppControlDisplayMode.dialog
                    ? Stack(
                        fit: StackFit.passthrough,
                        children: [
                          widget.child,
                          Positioned.fill(
                            child: Material(
                              color: Colors.black54,
                              type: MaterialType.canvas,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: widget.forceUpdateBuilder != null
                                      ? widget.forceUpdateBuilder!(
                                          context,
                                          platformConfig,
                                          currentVersion,
                                          isOffline,
                                          () => _cubit.checkConfig(),
                                        )
                                      : DefaultForceUpdateDialog(
                                          platformConfig: platformConfig,
                                          currentVersion: currentVersion,
                                          isOffline: isOffline,
                                          onRetry: () => _cubit.checkConfig(),
                                          primaryColor: widget.primaryColor,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : (widget.forceUpdateBuilder != null
                        ? widget.forceUpdateBuilder!(
                            context,
                            platformConfig,
                            currentVersion,
                            isOffline,
                            () => _cubit.checkConfig(),
                          )
                        : DefaultForceUpdateView(
                            platformConfig: platformConfig,
                            currentVersion: currentVersion,
                            isOffline: isOffline,
                            onRetry: () => _cubit.checkConfig(),
                            primaryColor: widget.primaryColor,
                          )),
              ),
            _ => effectiveChild,
          };
        },
      ),
    );

    if (Directionality.maybeOf(context) == null) {
      content = Directionality(
        textDirection: TextDirection.ltr,
        child: content,
      );
    }

    return content;
  }
}
