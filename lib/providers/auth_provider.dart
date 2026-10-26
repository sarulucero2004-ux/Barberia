import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? _user;
  String _nombre = '';
  String _apellido = '';
  String _rol = 'cliente';
  bool _isLoading = false;

  /// Identificador del barbero (B1 / B2) asociado a este usuario. Es el mismo
  /// campo `barberId` que ya existe en los documentos de `usuarios`, y se lee
  /// junto con el resto del perfil para no hacer consultas adicionales.
  String _barberId = '';

  User? get user => _user;
  String get uid => _user?.uid ?? '';
  String get email => _user?.email ?? '';
  String get nombre => _nombre;
  String get apellido => _apellido;
  String get nombreCompleto => '$_nombre $_apellido';
  String get role => _rol;
  String get barberId => _barberId;
  bool get isLoggedIn => _user != null;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _rol == 'admin';
  bool get isLoading => _isLoading;

  AuthProvider({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserData(user.uid);
    } else {
      _nombre = '';
      _apellido = '';
      _rol = 'cliente';
      _barberId = '';
    }
    notifyListeners();
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final data = await _firestoreService.getUserData(uid);
      if (data != null) {
        _nombre = data['nombre'] ?? '';
        _apellido = data['apellido'] ?? '';
        _rol = data['rol'] ?? 'cliente';
        _barberId = data['barberId'] ?? '';
      }
    } catch (_) {
      _nombre = _user?.email?.split('@')[0] ?? '';
      _apellido = '';
      _rol = 'cliente';
      _barberId = '';
    }
  }

  Future<String> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final rol = await _authService.login(email, password);
      return rol;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final rol = await _authService.signInWithGoogle();
      return rol;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.register(
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
  }
}
