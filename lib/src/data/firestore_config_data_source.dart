import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config.dart';

abstract class FirestoreConfigDataSource {
  Stream<AppConfig> watchConfig();
  Future<AppConfig> fetchConfig();
}

class FirestoreConfigDataSourceImpl implements FirestoreConfigDataSource {
  final FirebaseFirestore _firestore;
  final String _documentPath;

  FirestoreConfigDataSourceImpl({
    FirebaseFirestore? firestore,
    String documentPath = 'app_config/global',
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _documentPath = documentPath;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.doc(_documentPath);

  @override
  Stream<AppConfig> watchConfig() {
    return _docRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return AppConfig.fromMap(null);
      }
      return AppConfig.fromMap(snapshot.data());
    });
  }

  @override
  Future<AppConfig> fetchConfig() async {
    try {
      final snapshot = await _docRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return AppConfig.fromMap(null);
      }
      return AppConfig.fromMap(snapshot.data());
    } catch (_) {
      return AppConfig.fromMap(null);
    }
  }
}
