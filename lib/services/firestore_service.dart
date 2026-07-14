import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/barber.dart';
import '../models/service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return null;
    } on FirebaseException catch (e) {
      throw Exception('Error al obtener datos del usuario: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener datos del usuario.');
    }
  }

  // ── Services (public) ─────────────────────────────────────────────────────

  Future<List<Service>> getServices() async {
    try {
      final snapshot = await _db.collection('servicios').get();
      return snapshot.docs.map((doc) {
        return Service.fromMap(doc.data(), doc.id);
      }).toList();
    } on FirebaseException catch (e) {
      throw Exception('Error al cargar servicios: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al cargar servicios.');
    }
  }

  // ── Barbers (public) ──────────────────────────────────────────────────────

  Future<List<Barber>> getBarbers() async {
    try {
      final snapshot = await _db.collection('barberos').get();
      return snapshot.docs.map((doc) {
        return Barber.fromMap(doc.data(), doc.id);
      }).toList();
    } on FirebaseException catch (e) {
      throw Exception('Error al cargar barberos: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al cargar barberos.');
    }
  }

  // ── Appointments (public) ─────────────────────────────────────────────────

  Future<void> saveAppointment(Appointment appointment) async {
    try {
      final startTime = appointment.time.split(' - ').first;
      final parsedDate = appointment.getParsedDateTime() ?? DateTime.now();

      // Generar un ID único determinista basado en el barbero, la fecha y la hora del turno
      final slotId = '${appointment.barberId}_${appointment.date}_$startTime'
          .replaceAll(' ', '_')
          .replaceAll('/', '_');

      final docRef = _db.collection('turnos').doc(slotId);

      await _db.runTransaction((transaction) async {
        // Realizar la lectura previa (get) por referencia de documento en la transacción
        final docSnapshot = await transaction.get(docRef);

        if (docSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-booked',
            message: 'El turno acaba de ser reservado por alguien más',
          );
        }

        // Guardar el turno en la transacción
        transaction.set(docRef, {
          ...appointment.toMap(),
          'appointmentDateTime': Timestamp.fromDate(parsedDate),
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'already-booked') {
        throw Exception('El turno acaba de ser reservado por alguien más');
      }
      throw Exception('Error al guardar el turno: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al guardar el turno.');
    }
  }

  Stream<QuerySnapshot> getAppointmentsStream({String? date}) {
    if (date != null) {
      return _db
          .collection('turnos')
          .where('date', isEqualTo: date)
          .snapshots();
    }
    // Para la lista general de turnos, filtramos los que tengan fecha de hoy en adelante
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _db
        .collection('turnos')
        .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .snapshots();
  }

  Stream<List<Appointment>> getAppointmentsByDateAndBarber(
      String date, String barberId) {
    return _db
        .collection('turnos')
        .where('date', isEqualTo: date)
        .where('barberId', isEqualTo: barberId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<bool> checkExistingBooking(
      String date, String barberId, String startTime) async {
    try {
      final snapshot = await _db
          .collection('turnos')
          .where('date', isEqualTo: date)
          .where('barberId', isEqualTo: barberId)
          .where('startTime', isEqualTo: startTime)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      throw Exception('Error al verificar disponibilidad: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al verificar disponibilidad.');
    }
  }

  // ── Admin: Dashboard stats ────────────────────────────────────────────────

  int _countFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.length;
  }

  Future<int> getTodayAppointmentsCount(String todayDate) async {
    try {
      final snapshot = await _db
          .collection('turnos')
          .where('date', isEqualTo: todayDate)
          .get();
      return _countFromSnapshot(snapshot);
    } catch (e) {
      return 0;
    }
  }

  Future<int> getAppointmentsCountByStatus(AppointmentStatus status) async {
    try {
      final snapshot = await _db
          .collection('turnos')
          .where('status', isEqualTo: status.toJson())
          .get();
      return _countFromSnapshot(snapshot);
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTotalClients() async {
    try {
      final snapshot = await _db.collection('usuarios').get();
      return _countFromSnapshot(snapshot);
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getNextAppointment(String todayDate) async {
    try {
      final snapshot = await _db
          .collection('turnos')
          .where('date', isEqualTo: todayDate)
          .where('status', whereIn: [
            AppointmentStatus.pending.toJson(),
            AppointmentStatus.confirmed.toJson(),
          ])
          .orderBy('timestamp', descending: false)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Admin: Appointment CRUD ───────────────────────────────────────────────

  Future<void> updateAppointmentStatus(
      String appointmentId, AppointmentStatus newStatus) async {
    try {
      await _db.collection('turnos').doc(appointmentId).update({
        'status': newStatus.toJson(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar el estado: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar el estado.');
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _db.collection('turnos').doc(appointmentId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar el turno: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al eliminar el turno.');
    }
  }

  Future<void> updateAppointment(
      String appointmentId, Map<String, dynamic> data) async {
    try {
      await _db.collection('turnos').doc(appointmentId).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar el turno: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar el turno.');
    }
  }

  Future<bool> checkExistingBookingExcluding(
      String date, String barberId, String startTime,
      {String? excludeId}) async {
    try {
      Query query = _db
          .collection('turnos')
          .where('date', isEqualTo: date)
          .where('barberId', isEqualTo: barberId)
          .where('startTime', isEqualTo: startTime);

      final snapshot = await query.get();
      if (excludeId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }
      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      throw Exception('Error al verificar disponibilidad: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al verificar disponibilidad.');
    }
  }

  // ── Admin: Services CRUD ──────────────────────────────────────────────────

  Stream<QuerySnapshot> getServicesStream() {
    return _db.collection('servicios').snapshots();
  }

  Future<void> addService(Map<String, dynamic> data) async {
    try {
      await _db.collection('servicios').add(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar servicio: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al agregar servicio.');
    }
  }

  Future<void> updateService(
      String serviceId, Map<String, dynamic> data) async {
    try {
      await _db.collection('servicios').doc(serviceId).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar servicio: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar servicio.');
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      await _db.collection('servicios').doc(serviceId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar servicio: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al eliminar servicio.');
    }
  }

  // ── Admin: Barbers CRUD ──────────────────────────────────────────────────

  Stream<QuerySnapshot> getBarbersStream() {
    return _db.collection('barberos').snapshots();
  }

  Future<void> addBarber(Map<String, dynamic> data) async {
    try {
      await _db.collection('barberos').add(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al agregar barbero.');
    }
  }

  Future<void> updateBarber(String barberId, Map<String, dynamic> data) async {
    try {
      await _db.collection('barberos').doc(barberId).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar barbero.');
    }
  }

  Future<void> deleteBarber(String barberId) async {
    try {
      await _db.collection('barberos').doc(barberId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al eliminar barbero.');
    }
  }
}
