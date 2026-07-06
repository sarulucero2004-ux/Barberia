import 'dart:async';

import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/service.dart';
import 'firestore_service.dart';
import 'whatsapp_service.dart';

class BookingService {
  final FirestoreService _firestoreService;
  final WhatsAppService _whatsAppService;

  BookingService({
    required FirestoreService firestoreService,
    required WhatsAppService whatsAppService,
  })  : _firestoreService = firestoreService,
        _whatsAppService = whatsAppService;

  Stream<List<Appointment>> getAppointmentsByDateAndBarber(String date, String barberId) {
    return _firestoreService.getAppointmentsByDateAndBarber(date, barberId);
  }

  Future<void> confirmBooking({
    required String userId,
    required String customerName,
    required String customerEmail,
    required Barber barber,
    required Service service,
    required String date,
    required String time,
  }) async {
    final startTime = time.split(' - ').first;
    final isBooked = await _firestoreService.checkExistingBooking(date, barber.id, startTime);
    if (isBooked) {
      throw Exception('Este horario ya está reservado. Por favor, selecciona otro.');
    }

    final appointment = Appointment(
      id: '',
      userId: userId,
      customerName: customerName,
      customerEmail: customerEmail,
      barberId: barber.id,
      barberName: barber.name,
      barberPhone: barber.phone,
      serviceId: service.id,
      serviceName: service.name,
      servicePrice: service.price,
      date: date,
      time: time,
    );

    await _firestoreService.saveAppointment(appointment);

    await _whatsAppService.sendBookingMessage(appointment);
  }
}
