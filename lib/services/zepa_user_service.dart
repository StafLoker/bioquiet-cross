import 'package:firebase_database/firebase_database.dart';
import 'package:logging/logging.dart';

class ZepaUserService {
  static final _logger = Logger("ZepaUserService");
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("zepa_users");

  Future<void> registerUserPresence(String zepaId, String userId) async {
    try {
      final userRef = _dbRef.child(zepaId).child(userId);
      
      // Aseguramos que si el usuario pierde la conexión, se le elimine de la zona automáticamente
      await userRef.onDisconnect().remove();
      
      // Registramos la entrada
      await userRef.set(true);
      _logger.info("Usuario $userId registrado en la zona $zepaId");
    } catch (e) {
      _logger.severe("Error al registrar presencia en Firebase: $e");
    }
  }

  Future<void> removeUserPresence(String zepaId, String userId) async {
    try {
      await _dbRef.child(zepaId).child(userId).remove();
      _logger.info("Usuario $userId ha salido de la zona $zepaId");
    } catch (e) {
      _logger.severe("Error al eliminar presencia en Firebase: $e");
    }
  }

  Stream<int> watchUserCount(String zepaId) {
    return _dbRef.child(zepaId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return 0;
      return data.length;
    });
  }
}
