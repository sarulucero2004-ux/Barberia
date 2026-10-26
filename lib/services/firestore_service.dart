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
      final startTime = appointment.time.split(' - ').first.trim();
      final parsedDate = appointment.getParsedDateTime();
      if (parsedDate == null) {
        throw Exception('La fecha u hora del turno no es válida.');
      }

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
          'turnoId': slotId,
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

  String _slotIdFromTurno(Map<String, dynamic> data) {
    final barberId = '${data['barberId'] ?? ''}';
    final date = '${data['date'] ?? ''}';
    final startTime =
        '${data['startTime'] ?? '${data['time'] ?? ''}'.split(' - ').first}';

    return _buildSlotId(barberId: barberId, date: date, startTime: startTime);
  }

  Map<String, dynamic> _availabilityDataFromTurno(
    Map<String, dynamic> data, {
    required String turnoId,
  }) {
    return {
      'barberId': '${data['barberId'] ?? ''}',
      'date': '${data['date'] ?? ''}',
      'startTime':
          '${data['startTime'] ?? '${data['time'] ?? ''}'.split(' - ').first}',
      'status': '${data['status'] ?? AppointmentStatus.pending.toJson()}',
      'turnoId': turnoId,
    };
  }

  /// Un espejo pertenece al turno solo si lo declara (`turnoId`) o si su id es
  /// exactamente el id del turno. Sin esa prueba, borrarlo o sobrescribirlo
  /// podría destruir la disponibilidad de otro turno.
  bool _isMirrorOwnedBy(
    String mirrorId,
    Map<String, dynamic>? mirrorData,
    String turnoId,
  ) {
    if (mirrorData == null) return true;
    final owner = mirrorData['turnoId'];
    if (owner is String && owner.isNotEmpty) {
      return owner == turnoId;
    }
    return mirrorId == turnoId;
  }

  /// Evita que una acción iniciada con datos viejos (por ejemplo tras mover un
  /// turno y reutilizar el slot) afecte a un turno nuevo.
  void _assertExpectedIdentity(
    Map<String, dynamic> data, {
    Timestamp? expectedCreatedAt,
    String? expectedUserId,
  }) {
    if (expectedUserId != null && '${data['userId'] ?? ''}' != expectedUserId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'stale-appointment',
        message: 'El turno cambió desde que se cargó la lista.',
      );
    }
    if (expectedCreatedAt != null) {
      final actual = data['timestamp'];
      if (actual is! Timestamp ||
          actual.millisecondsSinceEpoch !=
              expectedCreatedAt.millisecondsSinceEpoch) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'stale-appointment',
          message: 'El turno cambió desde que se cargó la lista.',
        );
      }
    }
  }

  Future<void> updateAppointmentStatus(
      String appointmentId, AppointmentStatus newStatus,
      {Timestamp? expectedCreatedAt, String? expectedUserId}) async {
    try {
      await _db.runTransaction((transaction) async {
        final turnoRef = _db.collection('turnos').doc(appointmentId);
        final snapshot = await transaction.get(turnoRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'appointment-not-found',
            message: 'El turno ya no existe.',
          );
        }

        final turnoData = snapshot.data()!;
        _assertExpectedIdentity(
          turnoData,
          expectedCreatedAt: expectedCreatedAt,
          expectedUserId: expectedUserId,
        );

        final currentSlotId = _slotIdFromTurno(turnoData);
        if (currentSlotId != appointmentId) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'inconsistent-slot',
            message:
                'El turno tiene un horario que no coincide con su id; actualízalo antes de cambiar el estado.',
          );
        }

        final mirrorRef = _disponibilidad.doc(appointmentId);
        final mirrorSnapshot = await transaction.get(mirrorRef);
        if (mirrorSnapshot.exists &&
            !_isMirrorOwnedBy(
              appointmentId,
              mirrorSnapshot.data(),
              appointmentId,
            )) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'mirror-conflict',
            message:
                'La disponibilidad de ese horario pertenece a otro turno.',
          );
        }

        transaction.update(turnoRef, {'status': newStatus.toJson()});
        transaction.set(
          mirrorRef,
          _availabilityDataFromTurno(
            {...turnoData, 'status': newStatus.toJson()},
            turnoId: appointmentId,
          ),
          SetOptions(merge: true),
        );
      });
    } on FirebaseException catch (e) {
      if (e.code == 'appointment-not-found') {
        throw Exception('El turno ya no existe.');
      }
      if (e.code == 'stale-appointment') {
        throw Exception(
            'El turno cambió desde que se cargó la lista. Actualiza e inténtalo de nuevo.');
      }
      if (e.code == 'inconsistent-slot') {
        throw Exception(
            'El turno tiene un horario inconsistente; no se cambió ningún documento.');
      }
      if (e.code == 'mirror-conflict') {
        throw Exception(
            'La disponibilidad de ese horario no pertenece a este turno; no se cambió ningún documento.');
      }
      throw Exception('Error al actualizar el estado: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al actualizar el estado.');
    }
  }

  Future<void> deleteAppointment(String appointmentId,
      {Timestamp? expectedCreatedAt, String? expectedUserId}) async {
    try {
      await _db.runTransaction((transaction) async {
        final turnoRef = _db.collection('turnos').doc(appointmentId);
        final snapshot = await transaction.get(turnoRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'appointment-not-found',
            message: 'El turno ya no existe; no se eliminó nada.',
          );
        }

        final turnoData = snapshot.data()!;
        _assertExpectedIdentity(
          turnoData,
          expectedCreatedAt: expectedCreatedAt,
          expectedUserId: expectedUserId,
        );

        final currentSlotId = _slotIdFromTurno(turnoData);

        // Todas las lecturas van antes de cualquier escritura.
        final mirrorSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final id in <String>{currentSlotId, appointmentId}) {
          final mirrorSnapshot = await transaction.get(_disponibilidad.doc(id));
          if (mirrorSnapshot.exists &&
              !_isMirrorOwnedBy(
                id,
                mirrorSnapshot.data(),
                appointmentId,
              )) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'mirror-conflict',
              message:
                  'La disponibilidad de ese horario pertenece a otro turno.',
            );
          }
          mirrorSnapshots[id] = mirrorSnapshot;
        }

        transaction.delete(turnoRef);
        for (final entry in mirrorSnapshots.entries) {
          if (entry.value.exists) {
            transaction.delete(_disponibilidad.doc(entry.key));
          }
        }
      });
    } on FirebaseException catch (e) {
      if (e.code == 'appointment-not-found') {
        throw Exception('El turno ya no existe; no se eliminó nada.');
      }
      if (e.code == 'stale-appointment') {
        throw Exception(
            'El turno cambió desde que se cargó la lista. Actualiza e inténtalo de nuevo.');
      }
      if (e.code == 'mirror-conflict') {
        throw Exception(
            'La disponibilidad de ese horario no pertenece a este turno; no se eliminó nada.');
      }
      throw Exception('Error al eliminar el turno: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al eliminar el turno.');
    }
  }

  Future<void> updateAppointment(
      String appointmentId, Map<String, dynamic> data,
      {Timestamp? expectedCreatedAt, String? expectedUserId}) async {
    try {
      await _db.runTransaction((transaction) async {
        final turnoRef = _db.collection('turnos').doc(appointmentId);
        final snapshot = await transaction.get(turnoRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'appointment-not-found',
            message: 'El turno ya no existe.',
          );
        }

        final oldData = snapshot.data()!;
        _assertExpectedIdentity(
          oldData,
          expectedCreatedAt: expectedCreatedAt,
          expectedUserId: expectedUserId,
        );

        final oldSlotId = _slotIdFromTurno(oldData);
        final updatedData = <String, dynamic>{...oldData, ...data};
        final newSlotId = _slotIdFromTurno(updatedData);

        if (data['appointmentDateTime'] is Timestamp) {
          final expected = Appointment.parseSchedule(
            date: '${updatedData['date'] ?? ''}',
            time: '${updatedData['time'] ?? ''}',
          );
          final provided = data['appointmentDateTime'] as Timestamp;
          if (expected == null ||
              provided.toDate().year != expected.year ||
              provided.toDate().month != expected.month ||
              provided.toDate().day != expected.day ||
              provided.toDate().hour != expected.hour ||
              provided.toDate().minute != expected.minute) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'invalid-datetime',
              message:
                  'La fecha y hora del turno no coinciden con la fecha programada.',
            );
          }
        }

        // Espejos que este turno podría ocupar/vaciar. Se leen todos antes de
        // escribir para respetar el orden de las transacciones.
        final mirrorSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final id in <String>{oldSlotId, appointmentId}) {
          final mirrorSnapshot = await transaction.get(_disponibilidad.doc(id));
          if (mirrorSnapshot.exists &&
              !_isMirrorOwnedBy(
                id,
                mirrorSnapshot.data(),
                appointmentId,
              )) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'mirror-conflict',
              message:
                  'La disponibilidad de ese horario pertenece a otro turno.',
            );
          }
          mirrorSnapshots[id] = mirrorSnapshot;
        }

        if (newSlotId == appointmentId) {
          transaction.update(turnoRef, data);
          for (final entry in mirrorSnapshots.entries) {
            if (entry.key != appointmentId && entry.value.exists) {
              transaction.delete(_disponibilidad.doc(entry.key));
            }
          }
          transaction.set(
            _disponibilidad.doc(appointmentId),
            _availabilityDataFromTurno(updatedData, turnoId: appointmentId),
            SetOptions(merge: true),
          );
          return;
        }

        final newTurnoRef = _db.collection('turnos').doc(newSlotId);
        final targetSnapshot = await transaction.get(newTurnoRef);
        if (targetSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-booked',
            message: 'El horario ya se encuentra ocupado.',
          );
        }

        // Al mover se reescribe el documento completo, así que debe cumplir el
        // contrato estricto de las reglas. Los campos legacy desconocidos se
        // rechazan en vez de perderse silenciosamente.
        const allowedKeys = {
          'userId', 'customerName', 'customerEmail', 'barberId',
          'barberName', 'barberPhone', 'serviceId', 'serviceName',
          'servicePrice', 'date', 'time', 'startTime', 'status',
          'appointmentDateTime', 'timestamp',
        };
        final extraKeys = updatedData.keys
            .where((key) => !allowedKeys.contains(key))
            .toList();
        if (extraKeys.isNotEmpty) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'incompatible-fields',
            message:
                'El turno contiene campos no compatibles con el traslado: ${extraKeys.join(', ')}.',
          );
        }
        if (updatedData['appointmentDateTime'] is! Timestamp) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'invalid-datetime',
            message:
                'El turno no tiene una fecha y hora válidas para trasladarlo.',
          );
        }

        final targetMirrorSnapshot = mirrorSnapshots[newSlotId] ??
            await transaction.get(_disponibilidad.doc(newSlotId));
        if (targetMirrorSnapshot.exists &&
            !_isMirrorOwnedBy(
              newSlotId,
              targetMirrorSnapshot.data(),
              appointmentId,
            )) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'mirror-conflict',
            message:
                'Ya existe una disponibilidad que no pertenece a este turno en el horario destino.',
          );
        }

        // El id del turno es también el id del slot. Al mover ambos documentos
        // juntos se evita dejar un turno sin espejo o un espejo sin turno.
        transaction.set(newTurnoRef, updatedData);
        transaction.delete(turnoRef);
        for (final entry in mirrorSnapshots.entries) {
          if (entry.key != newSlotId && entry.value.exists) {
            transaction.delete(_disponibilidad.doc(entry.key));
          }
        }
        transaction.set(
          _disponibilidad.doc(newSlotId),
          _availabilityDataFromTurno(updatedData, turnoId: newSlotId),
          SetOptions(merge: true),
        );
      });
    } on FirebaseException catch (e) {
      if (e.code == 'already-booked') {
        throw Exception('El horario ya se encuentra ocupado.');
      }
      if (e.code == 'appointment-not-found') {
        throw Exception('El turno ya no existe.');
      }
      if (e.code == 'stale-appointment') {
        throw Exception(
            'El turno cambió desde que se cargó la lista. Actualiza e inténtalo de nuevo.');
      }
      if (e.code == 'mirror-conflict') {
        throw Exception(
            'La disponibilidad del horario no pertenece a este turno; no se realizaron cambios.');
      }
      if (e.code == 'incompatible-fields' || e.code == 'invalid-datetime') {
        throw Exception(e.message ?? 'El turno no se puede trasladar.');
      }
      throw Exception('Error al actualizar el turno: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
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
