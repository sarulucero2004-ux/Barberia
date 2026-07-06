import 'dart:async';

import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/service.dart';
import '../services/booking_service.dart';
import '../services/firestore_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService;
  final FirestoreService _firestoreService;

  List<Service> _services = [];
  List<Barber> _barbers = [];
  bool _isLoading = false;
  bool _isSaving = false;

  StreamSubscription<List<Appointment>>? _appointmentsSubscription;
  final Set<String> _bookedTimes = {};

  List<Service> get services => _services;
  List<Barber> get barbers => _barbers;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Set<String> get bookedTimes => _bookedTimes;

  BookingProvider({
    required BookingService bookingService,
    required FirestoreService firestoreService,
  })  : _bookingService = bookingService,
        _firestoreService = firestoreService;

  Future<void> loadServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      _services = await _firestoreService.getServices();
    } catch (_) {
      _services = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBarbers() async {
    try {
      _barbers = await _firestoreService.getBarbers();
      notifyListeners();
    } catch (_) {
      _barbers = [];
    }
  }

  void loadBookedTimes(String date, String barberId) {
    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _bookingService
        .getAppointmentsByDateAndBarber(date, barberId)
        .listen((appointments) {
      _bookedTimes
        ..clear()
        ..addAll(appointments.map((a) => a.time.split(' - ').first));
      notifyListeners();
    });
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
    _isSaving = true;
    notifyListeners();
    try {
      await _bookingService.confirmBooking(
        userId: userId,
        customerName: customerName,
        customerEmail: customerEmail,
        barber: barber,
        service: service,
        date: date,
        time: time,
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}
