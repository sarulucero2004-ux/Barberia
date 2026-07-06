import 'appointment_status.dart';

class Appointment {
  final String id;
  final String userId;
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

  Appointment({
    required this.id,
    required this.userId,
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
      userId: map['userId'] ?? '',
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
    );
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
    );
  }
}
