import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/business_schedule.dart';
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

  StreamSubscription<List<String>>? _appointmentsSubscription;
  StreamSubscription<List<Barber>>? _barbersSubscription;
  StreamSubscription<List<Service>>? _servicesSubscription;
  final Set<String> _bookedTimes = {};

  /// Estado de verificación de la disponibilidad del slot seleccionado.
  ///
  /// La agenda pública NO puede asumir que un horario está libre solo porque la
  /// consulta falló: `availabilityError` significa "no se pudo verificar", que
  /// es un estado distinto de "disponible" y por eso bloquea la selección.
  bool _availabilityError = false;
  bool _availabilityLoaded = false;

  /// Configuración de horarios de atención (`config/negocio`).
  ///
  /// `null` significa "no hay configuración válida disponible", que es un estado
  /// de ERROR y no una agenda vacía. No existe lista horaria hardcodeada de
  /// respaldo: si Firestore falla, la UI debe avisar y pedir reintentar en
  /// lugar de ofrecer todos los horarios como libres.
  BusinessSchedule? _schedule;
  StreamSubscription<BusinessSchedule>? _scheduleSubscription;
  bool _scheduleError = false;
  bool _scheduleLoaded = false;

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

  /// `true` cuando la consulta de disponibilidad falló: no se pudo verificar
  /// qué horarios están ocupados. La UI debe mostrar un error, nunca pintar
  /// todos los horarios como disponibles.
  bool get availabilityError => _availabilityError;

  /// `true` cuando hay una respuesta definitiva (correcta o con error). Mientras
  /// es `false` la disponibilidad está en vuelo y no se puede afirmar que un
  /// horario esté libre.
  bool get availabilityLoaded => _availabilityLoaded;

  /// Horarios de atención configurados en Firestore, o `null` si todavía no
  /// se pudieron leer.
  BusinessSchedule? get schedule => _schedule;

  /// `true` cuando la lectura de `config/negocio` falló. En ese estado NO se
  /// generan horarios: mostrarlos equivaldría a afirmar disponibilidad sin
  /// haber verificado la configuración.
  bool get scheduleError => _scheduleError;

  /// `true` cuando la configuración ya dio una respuesta definitiva.
  bool get scheduleLoaded => _scheduleLoaded;

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
    _listenToBarbers();
    _listenToServices();
    _listenToSchedule();
  }

  /// Escucha `config/negocio` en tiempo real para que los horarios se actualicen
  /// sin recargar la página.
  void _listenToSchedule() {
    _scheduleSubscription =
        _firestoreService.getBusinessScheduleStream().listen(
      (schedule) {
        _schedule = schedule;
        _scheduleError = false;
        _scheduleLoaded = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Se descarta la configuración en lugar de mantener una agenda vieja: sin
        // `config/negocio` no se puede afirmar qué horarios existen. La UI
        // muestra error y permite reintentar.
        debugPrint('Error al escuchar config/negocio desde Firestore: $error');
        debugPrintStack(stackTrace: stackTrace);
        _schedule = null;
        _scheduleError = true;
        _scheduleLoaded = true;
        notifyListeners();
      },
    );
  }

  /// Reintenta leer la configuración de horarios tras un error.
  void retrySchedule() {
    _scheduleSubscription?.cancel();
    _scheduleError = false;
    _scheduleLoaded = false;
    _schedule = null;
    notifyListeners();
    _listenToSchedule();
  }

  void _listenToBarbers() {
    _barbersSubscription = _firestoreService.getBarbersListStream().listen((barbers) {
      _barbers = barbers;
      notifyListeners();
    });
  }

  void _listenToServices() {
    _servicesSubscription = _firestoreService.getServicesListStream().listen(
      (services) {
        _services = services;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Sin este onError el fallo del stream se descarta en silencio: la
        // página principal queda vacía sin ningún indicio de la causa.
        debugPrint('Error al escuchar servicios desde Firestore: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
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
      final loaded = await _firestoreService.getServices();
      // La lista se mantiene actualizada por el stream (_listenToServices).
      // Esta lectura puntual solo trae el estado inicial, así que no debe
      // pisar con un resultado vacío una lista que el stream ya entregó.
      if (loaded.isNotEmpty) {
        _services = loaded;
      }
    } catch (_) {
      // Ante cualquier error se conserva lo que el stream ya entregó.
      // Antes se hacía `_services = []`, lo que vaciaba la página principal
      // aunque los servicios existieran en Firestore.
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
    // Se limpia el set anterior porque pertenece a otra fecha/barbero, pero
    // `_availabilityLoaded = false` impide que la UI lo interprete como
    // "no hay horarios ocupados": la disponibilidad queda "en vuelo".
    _bookedTimes.clear();
    _availabilityError = false;
    _availabilityLoaded = false;
    notifyListeners();
    _appointmentsSubscription = _bookingService
        .getAppointmentsByDateAndBarber(date, barberId)
        .listen(
      (bookedStartTimes) {
        _bookedTimes
          ..clear()
          ..addAll(bookedStartTimes);
        _availabilityError = false;
        _availabilityLoaded = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Un fallo de lectura significa "NO SE PUDO VERIFICAR LA
        // DISPONIBILIDAD", nunca "todo está disponible". Se marca el error y se
        // bloquea la selección; `_bookedTimes` NO se vacía para no perder la
        // ocupación conocida, y no se vuelve a notificar disponibilidad como si
        // fuera válida. La autoridad para rechazar una doble reserva sigue
        // siendo la transacción de `turnos`, no esta lista.
        debugPrint('No se pudo leer la disponibilidad: $error');
        _availabilityError = true;
        _availabilityLoaded = true;
        notifyListeners();
      },
    );
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
    _barbersSubscription?.cancel();
    _servicesSubscription?.cancel();
    _scheduleSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
