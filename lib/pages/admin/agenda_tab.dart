import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment.dart';
import '../../models/barber.dart';
import '../../models/business_schedule.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
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

  /// Genera la grilla de horarios del día desde `config/negocio`.
  ///
  /// La Agenda consume la MISMA configuración global que la reserva pública
  /// (horarios globales para B1 y B2), pero conserva su propio `TimeSlotInfo` y
  /// su lectura de `turnos`: no cambia la lógica de ocupación ni los filtros por
  /// `barberId`.
  List<TimeSlotInfo> _generateTimeSlots(BusinessSchedule schedule) {
    final step = schedule.slotMinutos;

    return schedule.getSlotsForWeekday(_selectedDate.weekday).map((start) {
      final parts = start.split(':');
      int hr = int.parse(parts[0]);
      int min = int.parse(parts[1]) + step;
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

  /// Convierte el snapshot de `barberos` en modelos, tolerando errores, datos
  /// nulos y documentos incompletos para no romper la Agenda.
  List<Barber> _parseBarbers(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) return const [];
    final data = snapshot.data;
    if (data == null) return const [];
    return data.docs
        .where((doc) => doc.data() != null)
        .map((doc) => Barber.fromMap(
            Map<String, dynamic>.from(doc.data()! as Map), doc.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.read<AdminProvider>();
    final isCompact = MediaQuery.of(context).size.width < 700;
    // Cada administrador administra únicamente su propio barbero. El `barberId`
    // sale del documento de `usuarios` (mismo campo que ya usan los turnos).
    final adminBarberId = context.watch<AuthProvider>().barberId;

    return Padding(
      padding: EdgeInsets.all(isCompact ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateNavigator(),
          const SizedBox(height: 24),
          Expanded(
            // Sin `barberId` no se puede acotar la consulta, y una consulta sin
            // acotar sería rechazada por las reglas. Se informa en vez de
            // mostrar la agenda de otro barbero.
            child: adminBarberId.isEmpty
                ? const Center(
                    child: Text(
                      'Tu cuenta no tiene un barbero asignado.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : StreamBuilder<BusinessSchedule>(
              stream: adminProvider.getBusinessScheduleStream(),
              builder: (context, scheduleSnapshot) {
                // La grilla depende de `config/negocio`. Si la configuración no
                // se pudo leer no se dibujan horarios: una grilla vacía o con
                // horarios supuestos sería información falsa.
                if (scheduleSnapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los horarios de atención.'),
                  );
                }
                if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  );
                }

                final schedule = scheduleSnapshot.data;
                if (schedule == null) {
                  return const Center(
                    child: Text('No se pudieron cargar los horarios de atención.'),
                  );
                }

                final slots = _generateTimeSlots(schedule);

                return StreamBuilder<QuerySnapshot>(
              stream: adminProvider.getBarbersStream(),
              builder: (context, barberSnapshot) {
                // Solo la columna del barbero de este administrador. El grid no
                // cambia de estructura: `itemCount` sigue siendo
                // `slots * barbers`, ahora con una única columna.
                final barbers = _parseBarbers(barberSnapshot)
                    .where((b) => b.id == adminBarberId)
                    .toList();
                return StreamBuilder<QuerySnapshot>(
                  stream: adminProvider.getAppointmentsStream(
                      date: _formattedDate, barberId: adminBarberId),
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

                    return _buildAgendaGrid(slots, appointments, barbers);
                  },
                );
              },
            );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator() {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final month = _monthsFull[_selectedDate.month - 1];
    final dateLabel = isCompact
        ? '${_selectedDate.day} de ${month.substring(0, 3)} de ${_selectedDate.year}'
        : _formattedDate;

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
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 24,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 20),
                SizedBox(width: isCompact ? 6 : 12),
                Flexible(
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
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

  Widget _buildAgendaGrid(List<TimeSlotInfo> slots, List<Appointment> appointments,
      List<Barber> barbers) {
    if (barbers.isEmpty) {
      return const Center(
        child: Text(
          'No hay barberos cargados.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
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
          // Una celda por combinación (horario, barbero). La disponibilidad se
          // calcula por barbero, así que un turno de Ezequiel no puede marcar el
          // mismo horario como ocupado para Isaías.
          itemCount: slots.length * barbers.length,
          itemBuilder: (context, index) {
            final slot = slots[index ~/ barbers.length];
            final barber = barbers[index % barbers.length];
            // La coincidencia usa barberId + hora de inicio. Antes solocomparaba
            // la hora, así que un turno de un barbero ocultaba el del otro y el
            // grid mostraba un único turno por horario.
            final appointment = appointments
                .where((a) =>
                    a.barberId == barber.id &&
                    a.time.split(' - ').first == slot.startTime)
                .firstOrNull;

            return _buildSlotCard(slot, appointment, barber.name);
          },
        );
      },
    );
  }

  Widget _buildSlotCard(TimeSlotInfo slot, Appointment? appointment, String barberName) {
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
                Text(
                  barberName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
