import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/barber.dart';
import '../models/business_schedule.dart';
import '../models/service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  /// Lee los barberos desde Firestore. No crea ni modifica documentos:
  /// la colección `barberos` es la única fuente de verdad.
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

  /// Horarios de atención del negocio, en `config/negocio`.
  ///
  /// Es una lectura ADITIVA e independiente de la disponibilidad: la
  /// configuración responde "¿qué horarios existen?" y `disponibilidad`
  /// responde "¿cuáles están ocupados?". No interviene en la transacción de
  /// `saveAppointment()` ni en la construcción del `slotId`.
  DocumentReference<Map<String, dynamic>> get _configNegocio =>
      _db.collection('config').doc('negocio');

  /// Emite la configuración de horarios en tiempo real, sin necesidad de
  /// recargar la página. Si el documento no existe o es inválido se lanza un
  /// error: nunca se devuelve una agenda vacía como si fuera válida, para que
  /// el provider pueda mostrar un estado de error en vez de ofrecer todos los
  /// horarios.
  Stream<BusinessSchedule> getBusinessScheduleStream() {
    return _configNegocio.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError(
            'No existe el documento config/negocio con los horarios de atención.');
      }
      return BusinessSchedule.fromMap(data);
    });
  }

  /// Colección pública de disponibilidad. Contiene únicamente barbero, fecha,
  /// hora de inicio y estado: ningún dato del cliente. Permite que la agenda
  /// pública consulte los horarios ocupados sin abrir `turnos`, que es privada.
  CollectionReference<Map<String, dynamic>> get _disponibilidad =>
      _db.collection('disponibilidad');

  /// ID determinista del slot. Debe generarse exactamente igual que el que usa
  /// `turnos` para que ambos documentos se correspondan por el mismo id.
  String _buildSlotId({
    required String barberId,
    required String date,
    required String startTime,
  }) {
    return '${barberId}_${date}_$startTime'
        .replaceAll(' ', '_')
        .replaceAll('/', '_');
  }

  Future<void> saveAppointment(Appointment appointment) async {
    try {
      final startTime = appointment.time.split(' - ').first;
      final parsedDate = appointment.getParsedDateTime() ?? DateTime.now();

      // Generar un ID único determinista basado en el barbero, la fecha y la hora del turno
      final slotId = _buildSlotId(
        barberId: appointment.barberId,
        date: appointment.date,
        startTime: startTime,
      );

      final docRef = _db.collection('turnos').doc(slotId);
      final disponibilidadRef = _disponibilidad.doc(slotId);

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

        // Espejo público de disponibilidad, escrito en la MISMA transacción que
        // protege contra la doble reserva. Al ser atómica, no puede quedar un
        // turno sin su disponibilidad ni una disponibilidad sin su turno.
        // No se copian datos del cliente: solo barbero, fecha, hora y estado.
        transaction.set(disponibilidadRef, {
          'barberId': appointment.barberId,
          'date': appointment.date,
          'startTime': startTime,
          'status': appointment.status.toJson(),
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

    Stream<QuerySnapshot> getAppointmentsStream({String? date, String? barberId}) {
      Query<Map<String, dynamic>> query = _db.collection('turnos');

      if (date != null) {
        query = query.where('date', isEqualTo: date);
      } else {
        // Para la lista general de turnos, filtramos los que tengan fecha de hoy en adelante
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query = query.where('appointmentDateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart));
      }

      // Separación por barbero: cada administrador consulta únicamente su
      // propio `barberId`. El filtro va en la query, no en la UI, porque las
      // reglas de Firestore exigen que la consulta acote el campo que la regla
      // evalúa por documento.
      if (barberId != null && barberId.isNotEmpty) {
        query = query.where('barberId', isEqualTo: barberId);
      }

      return query.snapshots();
    }

  /// Horas de inicio ya reservadas para un barbero en una fecha concreta.
  ///
  /// Se lee de `disponibilidad` (colección pública sin datos personales) en
  /// lugar de `turnos`, que exige autenticación y provocaba
  /// `permission-denied` en la agenda pública. Solo `cancelled` libera el
  /// horario: el resto de los estados (`pending`, `confirmed`, `completed`)
  /// siguen bloqueándolo.
  Stream<List<String>> getAppointmentsByDateAndBarber(
      String date, String barberId) {
    return _disponibilidad
        .where('date', isEqualTo: date)
        .where('barberId', isEqualTo: barberId)
        .where('status', isNotEqualTo: AppointmentStatus.cancelled.toJson())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => (doc.data()['startTime'] ?? '') as String)
            .where((startTime) => startTime.isNotEmpty)
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
      // Espejo de disponibilidad: al marcar el turno como `cancelled` deja de
      // bloquear el horario. Se propaga el estado en vez de borrar el documento
      // para que reactivar un turno cancelado vuelva a bloquearlo. `set` con
      // merge evita fallar si el documento todavía no existe (turnos creados
      // antes de que existiera la colección `disponibilidad`).
      await _disponibilidad.doc(appointmentId).set(
        {'status': newStatus.toJson()},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar el estado: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar el estado.');
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _db.collection('turnos').doc(appointmentId).delete();
      // `appointmentId` es el slotId, el mismo id usado en `disponibilidad`.
      // `delete` sobre un documento inexistente no lanza, por lo que los
      // turnos anteriores a esta colección no rompen el borrado.
      await _disponibilidad.doc(appointmentId).delete();
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
      await _syncAvailabilityAfterEdit(appointmentId, data);
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar el turno: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar el turno.');
    }
  }

  /// Mantiene alineado el espejo de disponibilidad tras editar un turno.
  ///
  /// `appointmentId` es el slotId original (ver `saveAppointment`), así que el
  /// documento viejo de disponibilidad se identifica con ese mismo id. Si la
  /// edición cambia barbero, fecha u hora, el slot es otro: se libera el
  /// anterior y se publica el nuevo, para no dejar bloqueando un horario que
  /// ya no tiene turno asociado.
  Future<void> _syncAvailabilityAfterEdit(
      String appointmentId, Map<String, dynamic> data) async {
    final newStatus = data['status']?.toString();
    if (newStatus != null) {
      await _disponibilidad.doc(appointmentId)
          .set({'status': newStatus}, SetOptions(merge: true));
    }

    const slotKeys = ['barberId', 'date', 'time', 'startTime'];
    if (!slotKeys.any(data.containsKey)) return;

    // Se relee el turno porque `update` ya aplicó los cambios: de ahí salen
    // los valores definitivos del nuevo slot.
    final snapshot = await _db.collection('turnos').doc(appointmentId).get();
    if (!snapshot.exists) return;
    final current = snapshot.data()!;

    final barberId = '${current['barberId'] ?? ''}';
    final date = '${current['date'] ?? ''}';
    final startTime = '${current['startTime'] ?? '${current['time'] ?? ''}'.split(' - ').first}';

    final newSlotId =
        _buildSlotId(barberId: barberId, date: date, startTime: startTime);

    if (newSlotId != appointmentId) {
      await _disponibilidad.doc(appointmentId).delete();
    }
    await _disponibilidad.doc(newSlotId).set({
      'barberId': barberId,
      'date': date,
      'startTime': startTime,
      'status': '${current['status'] ?? AppointmentStatus.pending.toJson()}',
    }, SetOptions(merge: true));
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

  Stream<List<Service>> getServicesListStream() {
    return _db.collection('servicios').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Service.fromMap(doc.data(), doc.id)).toList();
    });
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

  Stream<List<Barber>> getBarbersListStream() {
    return _db.collection('barberos').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Barber.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<String> uploadBarberImage(Uint8List bytes, String fileName) async {
    try {
      final ref = _storage
          .ref()
          .child('barberos')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Error al subir imagen del barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al subir la imagen.');
    }
  }

  /// Calcula el siguiente ID controlado para un barbero nuevo (B3, B4, ...).
  /// Nunca genera B1 ni B2: esos IDs están reservados y solo se crean a mano
  /// desde la consola de Firestore.
  Future<String> _nextBarberDocId() async {
    final snapshot = await _db.collection('barberos').get();
    var maxIndex = 1; // >= 1 para que el primer ID generado sea B3
    for (final doc in snapshot.docs) {
      final match = RegExp(r'^B(\d+)$').firstMatch(doc.id);
      if (match == null) continue;
      final index = int.tryParse(match.group(1)!);
      if (index != null && index > maxIndex) {
        maxIndex = index;
      }
    }
    return 'B${maxIndex + 1}';
  }

  /// Crea un barbero con un ID controlado (B3, B4, ...). Nunca usa `.add()`,
  /// para que el `docId` sea siempre determinista y comparable con `barberId`.
  Future<String> addBarber(Map<String, dynamic> data) async {
    try {
      final docId = await _nextBarberDocId();
      await _db.collection('barberos').doc(docId).set({
        ...data,
        'activo': data['activo'] ?? true,
      });
      return docId;
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al agregar barbero.');
    }
  }

  /// Actualiza SOLO el documento recibido. No crea documentos nuevos y no
  /// toca `activo` (u otros campos) porque `.update()` solo escribe las claves
  /// incluidas en `data`.
  Future<void> updateBarber(String barberId, Map<String, dynamic> data) async {
    try {
      await _db.collection('barberos').doc(barberId).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar barbero: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al actualizar barbero.');
    }
  }

  /// Elimina SOLO el documento cuyo ID coincide con `barberId`.
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
