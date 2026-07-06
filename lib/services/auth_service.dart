import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  Future<void> register({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario. Intente nuevamente.');
      }

      await _db.collection('usuarios').doc(user.uid).set({
        'uid': user.uid,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'rol': 'cliente',
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Este correo electrónico ya está registrado.');
        case 'invalid-email':
          throw Exception('El correo electrónico no es válido.');
        case 'weak-password':
          throw Exception('La contraseña debe tener al menos 6 caracteres.');
        default:
          throw Exception(e.message ?? 'Error al registrarse.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Ocurrió un error inesperado al registrarse.');
    }
  }

  Future<String> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('No se pudo iniciar sesión. Intente nuevamente.');
      }

      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception('No se encontraron datos de usuario.');
      }

      final rol = doc.data()!['rol'] as String? ?? 'cliente';
      return rol;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No existe una cuenta con este correo.');
        case 'wrong-password':
          throw Exception('Contraseña incorrecta.');
        case 'invalid-credential':
          throw Exception('Correo o contraseña incorrectos.');
        case 'invalid-email':
          throw Exception('El correo electrónico no es válido.');
        case 'user-disabled':
          throw Exception('Esta cuenta ha sido deshabilitada.');
        default:
          throw Exception(e.message ?? 'Error al iniciar sesión.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Ocurrió un error inesperado al iniciar sesión.');
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión.');
    }
  }
}
