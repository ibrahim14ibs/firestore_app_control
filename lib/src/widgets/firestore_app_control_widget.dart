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
/// forced updates, and optional update dialogs powered by Firebase Firestore.
class FirestoreAppControl extends StatefulWidget {
  /// The primary application widget tree.
  ///
  /// Displayed during normal application operation and underneath the optional
  /// update dialog.
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

  /// Navigator key used to display dialogs safely.
  ///
  /// If omitted, the widget automatically resolves the closest ancestor or
  /// descendant [NavigatorState].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Overrides the detected app version for testing purposes.
  ///
  /// When set, bypasses `PackageInfo.fromPlatform()`.
  final String? overrideVersion;

  /// Delay duration before displaying the optional update dialog.
  ///
  /// Useful to prevent dialogs from flashing on top of splash screens before
  /// initial navigation settles.
  final Duration? optionalUpdateDelay;

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
  });

  @override
  State<FirestoreAppControl> createState() => _FirestoreAppControlState();
}

class _FirestoreAppControlState extends State<FirestoreAppControl> {
  late final AppControlCubit _cubit;
  late final bool _internalCubit;
  bool _optionalDialogVisible = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _cubit.state;
      if (current is AppControlOptionalUpdate && !current.dismissedInSession) {
        _showOptionalDialog(context, current);
      }
    });
  }

  @override
  void dispose() {
    if (_internalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  BuildContext? _resolveNavigatorContext() {
    if (widget.navigatorKey?.currentContext != null) {
      return widget.navigatorKey!.currentContext;
    }
    final ancestor = Navigator.maybeOf(context, rootNavigator: true);
    if (ancestor != null) {
      return ancestor.context;
    }
    NavigatorState? descendantNav;
    void visitor(Element element) {
      if (element.widget is Navigator) {
        final state = (element as StatefulElement).state;
        if (state is NavigatorState) {
          descendantNav = state;
          return;
        }
      }
      if (descendantNav == null) {
        element.visitChildren(visitor);
      }
    }
    (context as Element).visitChildren(visitor);
    return descendantNav?.context;
  }

  void _showOptionalDialog(
    BuildContext context,
    AppControlOptionalUpdate state,
  ) {
    if (_optionalDialogVisible) return;
    _optionalDialogVisible = true;

    void present() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final targetContext = _resolveNavigatorContext() ?? context;

        void onDismiss() {
          _optionalDialogVisible = false;
          if (mounted) {
            _cubit.dismissOptionalUpdateForSession();
          }
        }

        try {
          if (widget.optionalUpdateBuilder != null) {
            widget.optionalUpdateBuilder!(
              targetContext,
              state.platformConfig,
              state.currentVersion,
              onDismiss,
            );
          } else {
            DefaultOptionalUpdateDialog.show(
              targetContext,
              platformConfig: state.platformConfig,
              currentVersion: state.currentVersion,
              onDismiss: onDismiss,
              primaryColor: widget.primaryColor,
            ).then((_) {
              onDismiss();
            }).catchError((_) {
              _optionalDialogVisible = false;
            });
          }
        } catch (_) {
          _optionalDialogVisible = false;
        }
      });
    }

    if (widget.optionalUpdateDelay != null &&
        widget.optionalUpdateDelay! > Duration.zero) {
      Future.delayed(widget.optionalUpdateDelay!, () {
        if (mounted) present();
      });
    } else {
      present();
    }
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
            _showOptionalDialog(context, state);
          }
        },
        builder: (context, state) {
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
            _ => widget.child,
          };
        },
      ),
    );
  }
}
