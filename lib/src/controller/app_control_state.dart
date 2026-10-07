import 'package:equatable/equatable.dart';
import '../models/app_config.dart';

sealed class AppControlState extends Equatable {
  const AppControlState();

  @override
  List<Object?> get props => [];
}

class AppControlInitial extends AppControlState {
  const AppControlInitial();
}

class AppControlLoading extends AppControlState {
  const AppControlLoading();
}

class AppControlNormal extends AppControlState {
  final AppConfig config;

  const AppControlNormal(this.config);

  @override
  List<Object?> get props => [config];
}

class AppControlMaintenance extends AppControlState {
  final MaintenanceConfig maintenance;

  const AppControlMaintenance(this.maintenance);

  @override
  List<Object?> get props => [maintenance];
}

class AppControlForceUpdate extends AppControlState {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final bool isOffline;

  const AppControlForceUpdate({
    required this.platformConfig,
    required this.currentVersion,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [platformConfig, currentVersion, isOffline];
}

class AppControlOptionalUpdate extends AppControlState {
  final PlatformConfig platformConfig;
  final String currentVersion;
  final bool dismissedInSession;

  const AppControlOptionalUpdate({
    required this.platformConfig,
    required this.currentVersion,
    this.dismissedInSession = false,
  });

  @override
  List<Object?> get props => [platformConfig, currentVersion, dismissedInSession];
}
