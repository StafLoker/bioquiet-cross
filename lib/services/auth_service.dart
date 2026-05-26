import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _log = Logger('AuthService');

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _log.info('User signed in: ${credential.user?.email}');
    return credential.user;
  }

  Future<User?> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _log.info('User registered: ${credential.user?.email}');
    return credential.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _log.info('User signed out');
  }
}
