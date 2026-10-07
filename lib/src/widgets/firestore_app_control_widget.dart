import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/app_control_cubit.dart';
import '../controller/app_control_state.dart';
import '../data/firestore_config_data_source.dart';
import '../models/app_config.dart';
import '../ui/default_force_update_view.dart';
import '../ui/default_maintenance_view.dart';
import '../ui/default_optional_update_dialog.dart';

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

typedef OptionalUpdateDialogBuilder = void Function(
  BuildContext context,
  PlatformConfig platformConfig,
  String currentVersion,
  VoidCallback onDismiss,
);

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

  /// Custom dialog builder or trigger for optional updates.
  ///
  /// If provided, completely replaces [DefaultOptionalUpdateDialog].
  final OptionalUpdateDialogBuilder? optionalUpdateBuilder;

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
  bool _isOverlayVisible = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
      _internalCubit = false;
    } else {
      final dataSource = FirestoreConfigDataSourceImpl(
        firestore: widget.firestore,
        documentPath: widget.documentPath,
      );
      _cubit = AppControlCubit(
        dataSource: dataSource,
        overrideVersion: widget.overrideVersion,
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
    if (!widget.autoShowOptionalUpdate) return;
    _delayTimer?.cancel();

    if (widget.optionalUpdateDelay != null &&
        widget.optionalUpdateDelay! > Duration.zero) {
      _delayTimer = Timer(widget.optionalUpdateDelay!, () {
        if (mounted) {
          setState(() => _isOverlayVisible = true);
        }
      });
    } else {
      _isOverlayVisible = true;
    }
  }

  void _dismissOverlay() {
    _delayTimer?.cancel();
    if (mounted) {
      setState(() => _isOverlayVisible = false);
    }
    _cubit.dismissOptionalUpdateForSession();
  }

  void _showOverlayManually() {
    final state = _cubit.state;
    if (state is AppControlOptionalUpdate && !state.dismissedInSession) {
      setState(() => _isOverlayVisible = true);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    if (_internalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AppControlCubit, AppControlState>(
        listenWhen: (prev, curr) =>
            curr is AppControlOptionalUpdate && !curr.dismissedInSession,
        listener: (context, state) {
          if (state is AppControlOptionalUpdate && !state.dismissedInSession) {
            if (widget.optionalUpdateBuilder != null) {
              widget.optionalUpdateBuilder!(
                context,
                state.platformConfig,
                state.currentVersion,
                _dismissOverlay,
              );
            } else {
              _scheduleOverlay(state);
            }
          }
        },
        builder: (context, state) {
          final showOverlay = _isOverlayVisible &&
              state is AppControlOptionalUpdate &&
              !state.dismissedInSession &&
              widget.optionalUpdateBuilder == null;

          final effectiveChild = Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              if (showOverlay)
                Positioned.fill(
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
                              child: DefaultOptionalUpdateDialog(
                                platformConfig: state.platformConfig,
                                currentVersion: state.currentVersion,
                                onDismiss: _dismissOverlay,
                                primaryColor: widget.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );

          return switch (state) {
            AppControlMaintenance(:final maintenance) =>
              widget.maintenanceBuilder != null
                  ? widget.maintenanceBuilder!(
                      context,
                      maintenance,
                      () => _cubit.checkConfig(),
                    )
                  : DefaultMaintenanceView(
                      maintenance: maintenance,
                      onRetry: () => _cubit.checkConfig(),
                      primaryColor: widget.primaryColor,
                    ),
            AppControlForceUpdate(
              :final platformConfig,
              :final currentVersion,
              :final isOffline,
            ) =>
              widget.forceUpdateBuilder != null
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
                    ),
            _ => effectiveChild,
          };
        },
      ),
    );
  }
}
