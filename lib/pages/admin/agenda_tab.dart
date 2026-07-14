import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment.dart';
import '../../providers/admin_provider.dart';
import '../../models/appointment_status.dart';

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  late DateTime _selectedDate;
  final List<String> _monthsFull = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _formattedDate =>
      '${_selectedDate.day} de ${_monthsFull[_selectedDate.month - 1]} de ${_selectedDate.year}';

  List<TimeSlotInfo> _generateTimeSlots() {
    final List<String> hours = [
      '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
      '12:00', '12:30', '13:00', '13:30', '16:00', '16:30',
      '17:00', '17:30', '18:00', '18:30', '19:00', '19:30'
    ];

    return hours.map((start) {
      final parts = start.split(':');
      int hr = int.parse(parts[0]);
      int min = int.parse(parts[1]) + 30;
      if (min >= 60) {
        hr += 1;
        min -= 60;
      }
      final end = '${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
      return TimeSlotInfo(startTime: start, endTime: end);
    }).toList();
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.read<AdminProvider>();
    final slots = _generateTimeSlots();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateNavigator(),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminProvider.getAppointmentsStream(date: _formattedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  );
                }

                final appointments = <Appointment>[];
                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['date'] == _formattedDate &&
                        data['status'] != AppointmentStatus.cancelled.toJson()) {
                      appointments.add(Appointment.fromMap(data, doc.id));
                    }
                  }
                }

                return _buildAgendaGrid(slots, appointments);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator() {
    return Row(
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: _previousDay,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 12),
              Text(
                _formattedDate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
          onPressed: _nextDay,
        ),
      ],
    );
  }

  Widget _buildAgendaGrid(List<TimeSlotInfo> slots, List<Appointment> appointments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final appointment = appointments.where((a) {
              return a.time.startsWith(slot.startTime);
            }).firstOrNull;

            return _buildSlotCard(slot, appointment);
          },
        );
      },
    );
  }

  Widget _buildSlotCard(TimeSlotInfo slot, Appointment? appointment) {
    if (appointment == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${slot.startTime} - ${slot.endTime}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Disponible',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final statusColor = _statusColor(appointment.status);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${slot.startTime} - ${slot.endTime}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.customerName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${appointment.serviceName} | ${appointment.barberName}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              appointment.status.displayName,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return const Color(0xFFFF9800);
      case AppointmentStatus.confirmed:
        return const Color(0xFF4CAF50);
      case AppointmentStatus.cancelled:
        return const Color(0xFFF44336);
      case AppointmentStatus.completed:
        return const Color(0xFF9C27B0);
    }
  }
}

class TimeSlotInfo {
  final String startTime;
  final String endTime;

  TimeSlotInfo({required this.startTime, required this.endTime});
}
