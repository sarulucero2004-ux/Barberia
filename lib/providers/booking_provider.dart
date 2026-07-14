import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
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

  Barber? _pendingBarber;
  Service? _pendingService;
  String? _pendingDate;
  String? _pendingTime;

  Appointment? _lastConfirmedAppointment;
  Future<void>? _currentBookingFuture;
  StreamSubscription<User?>? _authSubscription;

  List<Service> get services => _services;
  List<Barber> get barbers => _barbers;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Set<String> get bookedTimes => _bookedTimes;

  Barber? get pendingBarber => _pendingBarber;
  Service? get pendingService => _pendingService;
  String? get pendingDate => _pendingDate;
  String? get pendingTime => _pendingTime;
  bool get hasPendingBooking => _pendingBarber != null && _pendingService != null && _pendingDate != null && _pendingTime != null;

  BookingProvider({
    required BookingService bookingService,
    required FirestoreService firestoreService,
  })  : _bookingService = bookingService,
        _firestoreService = firestoreService {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user != null && hasPendingBooking) {
      final barber = _pendingBarber!;
      final service = _pendingService!;
      final date = _pendingDate!;
      final time = _pendingTime!;

      // Limpiar datos pendientes inmediatamente para evitar triggers duplicados
      clearPendingBooking();

      try {
        final userData = await _firestoreService.getUserData(user.uid);
        final String name = userData != null && userData['nombre'] != null
            ? '${userData['nombre']} ${userData['apellido'] ?? ''}'.trim()
            : (user.email?.split('@').first ?? 'Cliente');
        final String email = user.email ?? '';

        await confirmBooking(
          userId: user.uid,
          customerName: name.isNotEmpty ? name : email,
          customerEmail: email,
          barber: barber,
          service: service,
          date: date,
          time: time,
        );
      } catch (e) {
        debugPrint('Error al confirmar reserva automática tras inicio de sesión: $e');
      }
    }
  }

  void saveTemporaryBooking({
    required Barber barber,
    required Service service,
    required String date,
    required String time,
  }) {
    _pendingBarber = barber;
    _pendingService = service;
    _pendingDate = date;
    _pendingTime = time;
    notifyListeners();
  }

  void clearPendingBooking() {
    _pendingBarber = null;
    _pendingService = null;
    _pendingDate = null;
    _pendingTime = null;
    notifyListeners();
  }

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
    // Si ya hay una operación de confirmación en curso para este turno exacto, esperamos a que termine.
    if (_currentBookingFuture != null &&
        _pendingBarber?.id == barber.id &&
        _pendingDate == date &&
        _pendingTime == time) {
      await _currentBookingFuture;
      return;
    }

    // Si la última reserva exitosa coincide exactamente con la solicitada, retornamos directamente.
    if (_lastConfirmedAppointment != null &&
        _lastConfirmedAppointment!.barberId == barber.id &&
        _lastConfirmedAppointment!.date == date &&
        _lastConfirmedAppointment!.time == time) {
      return;
    }

    _isSaving = true;
    notifyListeners();

    final completer = Completer<void>();
    _currentBookingFuture = completer.future;

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

      _lastConfirmedAppointment = Appointment(
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

      if (_pendingBarber?.id == barber.id &&
          _pendingDate == date &&
          _pendingTime == time) {
        clearPendingBooking();
      }

      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _isSaving = false;
      _currentBookingFuture = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
