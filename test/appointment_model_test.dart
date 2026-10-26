import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barberia/models/appointment.dart';

Appointment _appointment({
  String date = '10 de octubre de 2026',
  String time = '10:00 - 10:30',
  DateTime? appointmentDateTime,
  DateTime? createdAt,
}) {
  return Appointment(
    id: 'turno',
    userId: 'clientA',
    customerName: 'Cliente',
    customerEmail: 'cliente@test.local',
    barberId: 'B1',
    barberName: 'Barbero',
    barberPhone: '3000000000',
    serviceId: 'servicio-corte',
    serviceName: 'Corte',
    servicePrice: 25000,
    date: date,
    time: time,
    appointmentDateTime: appointmentDateTime,
    createdAt: createdAt,
  );
}

void main() {
  group('Appointment.parseSchedule', () {
    test('interpreta una fecha y hora válidas', () {
      final parsed = Appointment.parseSchedule(
        date: '10 de octubre de 2026',
        time: '10:00 - 10:30',
      );
      expect(parsed, DateTime(2026, 10, 10, 10, 0));
    });

    test('devuelve null para una fecha imposible', () {
      expect(
        Appointment.parseSchedule(
          date: '31 de febrero de 2026',
          time: '10:00',
        ),
        isNull,
      );
    });

    test('devuelve null para un mes desconocido', () {
      expect(
        Appointment.parseSchedule(
          date: '10 de trecembro de 2026',
          time: '10:00',
        ),
        isNull,
      );
    });

    test('devuelve null para una hora fuera de rango', () {
      expect(
        Appointment.parseSchedule(
          date: '10 de octubre de 2026',
          time: '24:00',
        ),
        isNull,
      );
    });

    test('devuelve null para minutos fuera de rango', () {
      expect(
        Appointment.parseSchedule(
          date: '10 de octubre de 2026',
          time: '10:60',
        ),
        isNull,
      );
    });

    test('devuelve null para un formato de hora inválido', () {
      expect(
        Appointment.parseSchedule(
          date: '10 de octubre de 2026',
          time: 'diez',
        ),
        isNull,
      );
    });
  });

  group('Appointment.hasConsistentAppointmentDateTime', () {
    test('acepta una fecha guardada que coincide al minuto', () {
      final appointment = _appointment(
        appointmentDateTime: DateTime(2026, 10, 10, 10, 0),
      );
      expect(appointment.hasConsistentAppointmentDateTime(), isTrue);
    });

    test('rechaza una fecha guardada incoherente', () {
      final appointment = _appointment(
        appointmentDateTime: DateTime(2026, 10, 11, 10, 0),
      );
      expect(appointment.hasConsistentAppointmentDateTime(), isFalse);
    });

    test('rechaza cuando no hay fecha guardada', () {
      expect(_appointment().hasConsistentAppointmentDateTime(), isFalse);
    });

    test('rechaza cuando la fecha de texto es imposible', () {
      final appointment = _appointment(
        date: '31 de febrero de 2026',
        appointmentDateTime: DateTime(2026, 2, 28, 10, 0),
      );
      expect(appointment.hasConsistentAppointmentDateTime(), isFalse);
    });
  });

  group('Appointment.fromMap', () {
    test('lee createdAt desde timestamp para proteger acciones con datos viejos',
        () {
      final timestamp = Timestamp.fromDate(DateTime(2026, 10, 1, 8, 30));
      final appointment = Appointment.fromMap({
        'userId': 'clientA',
        'customerName': 'Cliente',
        'customerEmail': 'cliente@test.local',
        'barberId': 'B1',
        'barberName': 'Barbero',
        'barberPhone': '3000000000',
        'serviceId': 'servicio-corte',
        'serviceName': 'Corte',
        'servicePrice': 25000,
        'date': '10 de octubre de 2026',
        'time': '10:00 - 10:30',
        'status': 'pending',
        'appointmentDateTime':
            Timestamp.fromDate(DateTime(2026, 10, 10, 10, 0)),
        'timestamp': timestamp,
      }, 'turno');

      expect(appointment.createdAt, timestamp.toDate());
      expect(appointment.appointmentDateTime, DateTime(2026, 10, 10, 10, 0));
      expect(appointment.hasConsistentAppointmentDateTime(), isTrue);
    });
  });
}
