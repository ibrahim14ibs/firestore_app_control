import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config.dart';
import '../utils/app_control_logger.dart';

abstract class FirestoreConfigDataSource {
  Stream<AppConfig> watchConfig();
  Future<AppConfig> fetchConfig();
}

class FirestoreConfigDataSourceImpl implements FirestoreConfigDataSource {
  final FirebaseFirestore _firestore;
  final String _documentPath;
  final AppControlLogContext _logger;

  FirestoreConfigDataSourceImpl({
    FirebaseFirestore? firestore,
    String documentPath = 'app_config/global',
    bool? enableLogging,
    AppControlLogHandler? logHandler,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _documentPath = documentPath,
        _logger = AppControlLogContext(
          enableLogging: enableLogging,
          logHandler: logHandler,
        ) {
    _logger.info(
      'FirestoreConfigDataSourceImpl initialized with documentPath: "$_documentPath"',
    );
  }

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.doc(_documentPath);

  @override
  Stream<AppConfig> watchConfig() {
    _logger.info(
      'Subscribing to Firestore document snapshots at "$_documentPath"',
    );
    return _docRef
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            _logger.warning(
              'Document snapshot at "$_documentPath" does not exist. Using fallback defaults.',
            );
            return AppConfig.fromMap(null);
          }
          final data = snapshot.data();
          if (data == null) {
            _logger.warning(
              'Document snapshot at "$_documentPath" contains null data. Using fallback defaults.',
            );
            return AppConfig.fromMap(null);
          }
          final config = AppConfig.fromMap(data);
          _logger.info(
            'Received Firestore snapshot update from "$_documentPath" '
            '(maintenance: ${config.maintenance.enabled}, '
            'android: [min: ${config.android.minimumVersion}, latest: ${config.android.latestVersion}], '
            'ios: [min: ${config.ios.minimumVersion}, latest: ${config.ios.latestVersion}])',
          );
          return config;
        })
        .handleError((error, stackTrace) {
          _logger.error(
            'Error in Firestore snapshot stream at "$_documentPath": $error',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  @override
  Future<AppConfig> fetchConfig() async {
    _logger.info('Fetching one-time config snapshot from "$_documentPath"...');
    try {
      final snapshot = await _docRef.get();
      if (!snapshot.exists) {
        _logger.warning(
          'Fetched document snapshot at "$_documentPath" does not exist. Returning fallback defaults.',
        );
        return AppConfig.fromMap(null);
      }
      final data = snapshot.data();
      if (data == null) {
        _logger.warning(
          'Fetched document snapshot at "$_documentPath" contains null data. Returning fallback defaults.',
        );
        return AppConfig.fromMap(null);
      }
      final config = AppConfig.fromMap(data);
      _logger.info(
        'Successfully fetched config from "$_documentPath" '
        '(maintenance: ${config.maintenance.enabled})',
      );
      return config;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to fetch config snapshot from "$_documentPath": $error',
        error: error,
        stackTrace: stackTrace,
      );
      return AppConfig.fromMap(null);
    }
  }
}
