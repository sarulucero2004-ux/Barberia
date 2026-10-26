import 'package:cloud_firestore/cloud_firestore.dart';

import 'appointment_status.dart';

class Appointment {
  final String id;
  final String? userId;
  final String customerName;
  final String customerEmail;
  final String barberId;
  final String barberName;
  final String barberPhone;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final String date;
  final String time;
  final AppointmentStatus status;
  final DateTime? appointmentDateTime;
  final DateTime? createdAt;

  Appointment({
    required this.id,
    this.userId,
    required this.customerName,
    required this.customerEmail,
    required this.barberId,
    required this.barberName,
    required this.barberPhone,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.date,
    required this.time,
    this.status = AppointmentStatus.pending,
    this.appointmentDateTime,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'barberId': barberId,
      'barberName': barberName,
      'barberPhone': barberPhone,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'date': date,
      'time': time,
      'startTime': time.split(' - ').first,
      'status': status.toJson(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String docId) {
    return Appointment(
      id: docId,
      userId: map['userId'],
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      barberPhone: map['barberPhone'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      servicePrice: (map['servicePrice'] ?? 0.0).toDouble(),
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      status: AppointmentStatus.fromString(map['status'] ?? 'pending'),
      appointmentDateTime: _toDateTime(map['appointmentDateTime']),
      createdAt: _toDateTime(map['timestamp']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Appointment copyWith({
    String? id,
    String? userId,
    String? customerName,
    String? customerEmail,
    String? barberId,
    String? barberName,
    String? barberPhone,
    String? serviceId,
    String? serviceName,
    double? servicePrice,
    String? date,
    String? time,
    AppointmentStatus? status,
    DateTime? appointmentDateTime,
    DateTime? createdAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      barberId: barberId ?? this.barberId,
      barberName: barberName ?? this.barberName,
      barberPhone: barberPhone ?? this.barberPhone,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      servicePrice: servicePrice ?? this.servicePrice,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const Map<String, int> _months = {
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };

  /// Interpreta el formato "4 de Julio de 2026" + "09:00" sin normalizar.
  ///
  /// Devuelve `null` si la fecha o la hora son imposibles (por ejemplo
  /// "31 de febrero" o "25:00"). No asume enero ni deja que [DateTime] corrija
  /// un desbordamiento de día/mes, porque eso convertiría un turno inválido en
  /// un turno silenciosamente distinto.
  static DateTime? parseSchedule({required String date, required String time}) {
    final cleanDate = date.toLowerCase().trim();
    final parts = cleanDate.split(' de ');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0].trim());
    final month = _months[parts[1].trim()];
    final year = int.tryParse(parts[2].trim());
    if (day == null || month == null || year == null) return null;
    if (year < 2000 || year > 2100) return null;

    final startTimeStr = time.split(' - ').first.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(startTimeStr);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;

    final parsed = DateTime(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }
    return parsed;
  }

  DateTime? getParsedDateTime() => parseSchedule(date: date, time: time);

  /// `true` solo si el documento guarda una fecha/hora que coincide al minuto
  /// con la que se deduce de `date` + `time`.
  bool hasConsistentAppointmentDateTime() {
    final parsed = getParsedDateTime();
    final stored = appointmentDateTime;
    if (parsed == null || stored == null) return false;
    return parsed.year == stored.year &&
        parsed.month == stored.month &&
        parsed.day == stored.day &&
        parsed.hour == stored.hour &&
        parsed.minute == stored.minute;
  }
}
