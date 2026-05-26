import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _service.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) =>
      _authenticate(() => _service.signIn(email, password));

  Future<bool> signUp(String email, String password) =>
      _authenticate(() => _service.signUp(email, password));

  Future<void> signOut() => _service.signOut();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _authenticate(Future<User?> Function() call) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await call();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _mapError(String code) => switch (code) {
        'user-not-found' => 'No existe una cuenta con ese email.',
        'wrong-password' || 'invalid-credential' => 'Email o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con ese email.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        'invalid-email' => 'El formato del email no es válido.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
        _ => 'Error de autenticación ($code).',
      };
}
