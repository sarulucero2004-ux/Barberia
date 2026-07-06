import 'package:flutter/material.dart';
import '../models/appointment_status.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  AdminProvider({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Dashboard stats ───────────────────────────────────────────────────────

  int todayCount = 0;
  int pendingCount = 0;
  int confirmedCount = 0;
  int cancelledCount = 0;
  int completedCount = 0;
  int totalClients = 0;
  Map<String, dynamic>? nextAppointment;

  Future<void> loadDashboardStats(String todayDate) async {
    _isLoading = true;
    notifyListeners();
    try {
      todayCount = await _firestoreService.getTodayAppointmentsCount(todayDate);
      pendingCount =
          await _firestoreService.getAppointmentsCountByStatus(AppointmentStatus.pending);
      confirmedCount =
          await _firestoreService.getAppointmentsCountByStatus(AppointmentStatus.confirmed);
      cancelledCount =
          await _firestoreService.getAppointmentsCountByStatus(AppointmentStatus.cancelled);
      completedCount =
          await _firestoreService.getAppointmentsCountByStatus(AppointmentStatus.completed);
      totalClients = await _firestoreService.getTotalClients();
      nextAppointment = await _firestoreService.getNextAppointment(todayDate);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // ── Appointments ──────────────────────────────────────────────────────────
  Stream<QuerySnapshot> getAppointmentsStream() {
  return _firestoreService.getAppointmentsStream();
  }

  Stream<QuerySnapshot> getServicesStream() {
  return _firestoreService.getServicesStream();
  }

  Stream<QuerySnapshot> getBarbersStream() {
  return _firestoreService.getBarbersStream();
}

  Future<void> updateAppointmentStatus(
      String appointmentId, AppointmentStatus status) async {
    await _firestoreService.updateAppointmentStatus(appointmentId, status);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _firestoreService.deleteAppointment(appointmentId);
  }

  Future<void> updateAppointment(
      String appointmentId, Map<String, dynamic> data) async {
    await _firestoreService.updateAppointment(appointmentId, data);
  }

  Future<bool> checkAvailabilityExcluding(
      String date, String barberId, String startTime,
      {String? excludeId}) async {
    return await _firestoreService.checkExistingBookingExcluding(
        date, barberId, startTime,
        excludeId: excludeId);
  }

  // ── Services ──────────────────────────────────────────────────────────────

  Future<void> addService(String name, String description, double price,
      int durationMinutes) async {
    await _firestoreService.addService({
      'nombre': name,
      'descripcion': description,
      'precio': price,
      'duracion': durationMinutes,
    });
  }

  Future<void> updateService(
      String serviceId, String name, String description, double price,
      int durationMinutes) async {
    await _firestoreService.updateService(serviceId, {
      'nombre': name,
      'descripcion': description,
      'precio': price,
      'duracion': durationMinutes,
    });
  }

  Future<void> deleteService(String serviceId) async {
    await _firestoreService.deleteService(serviceId);
  }

  // ── Barbers ───────────────────────────────────────────────────────────────

  Future<void> addBarber(
      String name, String phone, String imageUrl, String specialty,
      double rating) async {
    await _firestoreService.addBarber({
      'nombre': name,
      'telefono': phone,
      'imagenUrl': imageUrl,
      'especialidad': specialty,
      'puntuacion': rating,
    });
  }

  Future<void> updateBarber(
      String barberId, String name, String phone, String imageUrl,
      String specialty, double rating) async {
    await _firestoreService.updateBarber(barberId, {
      'nombre': name,
      'telefono': phone,
      'imagenUrl': imageUrl,
      'especialidad': specialty,
      'puntuacion': rating,
    });
  }

  Future<void> deleteBarber(String barberId) async {
    await _firestoreService.deleteBarber(barberId);
  }
}
