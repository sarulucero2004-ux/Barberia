import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../models/appointment_status.dart';
import '../../models/appointment.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  String _searchQuery = '';
  AppointmentStatus? _statusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.read<AdminProvider>();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilters(),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminProvider.getAppointmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                var appointments = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Appointment.fromMap(data, doc.id);
                }).toList();

                appointments = _applyFilters(appointments);
                appointments.sort((a, b) {
                  final dateCmp = b.date.compareTo(a.date);
                  if (dateCmp != 0) return dateCmp;
                  return b.time.compareTo(a.time);
                });

                if (appointments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron turnos.',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    return _AppointmentCard(
                      appointment: appointments[index],
                      onChanged: () => setState(() {}),
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

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, barbero, fecha...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
            const SizedBox(width: 16),
            _buildStatusFilter(),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0x33FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppointmentStatus?>(
          value: _statusFilter,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          hint: const Text('Todos los estados', style: TextStyle(color: Colors.white54)),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Todos', style: TextStyle(color: Colors.white70)),
            ),
            ...AppointmentStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.displayName, style: TextStyle(color: _statusColor(status))),
              );
            }),
          ],
          onChanged: (value) => setState(() => _statusFilter = value),
        ),
      ),
    );
  }

  List<Appointment> _applyFilters(List<Appointment> appointments) {
    var filtered = appointments;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        return a.customerName.toLowerCase().contains(_searchQuery) ||
            a.barberName.toLowerCase().contains(_searchQuery) ||
            a.date.toLowerCase().contains(_searchQuery) ||
            a.status.displayName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (_statusFilter != null) {
      filtered = filtered.where((a) => a.status == _statusFilter).toList();
    }

    return filtered;
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

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onChanged;

  const _AppointmentCard({
    required this.appointment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _detailRow(Icons.content_cut, 'Servicio', appointment.serviceName),
                  _detailRow(Icons.person, 'Barbero', appointment.barberName),
                  _detailRow(Icons.calendar_today, 'Fecha', appointment.date),
                  _detailRow(Icons.access_time, 'Hora', appointment.time),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusDropdown(context),
                const SizedBox(height: 8),
                if (appointment.status != AppointmentStatus.cancelled)
                  _buildCancelButton(context),
                const SizedBox(height: 8),
                _buildEditButton(context),
                const SizedBox(height: 8),
                _buildDeleteButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppointmentStatus>(
          value: appointment.status,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: AppointmentStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(
                status.displayName,
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null || value == appointment.status) return;
            try {
              await context.read<AdminProvider>().updateAppointmentStatus(
                    appointment.id,
                    value,
                  );
              onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Estado actualizado a "${value.displayName}"'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      width: 130,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF9800),
          side: const BorderSide(color: Color(0xFFFF9800)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () => _confirmCancel(context),
        child: const Text('Cancelar Turno', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Cancelar Turno', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de cancelar este turno?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performCancel(context);
            },
            child: const Text('Sí, Cancelar', style: TextStyle(color: Color(0xFFFF9800))),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancel(BuildContext context) async {
    try {
      await context.read<AdminProvider>().updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.cancelled,
          );
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno cancelado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildEditButton(BuildContext context) {
    return SizedBox(
      width: 130,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2196F3),
          side: const BorderSide(color: Color(0xFF2196F3)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () => _showEditDialog(context),
        child: const Text('Editar Turno', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return SizedBox(
      width: 130,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF44336),
          side: const BorderSide(color: Color(0xFFF44336)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () => _confirmDelete(context),
        child: const Text('Eliminar Turno', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eliminar Turno', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de eliminar este turno? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performDelete(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFF44336))),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(BuildContext context) async {
    try {
      await context.read<AdminProvider>().deleteAppointment(appointment.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno eliminado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EditAppointmentDialog(
        appointment: appointment,
        onSaved: onChanged,
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

class _EditAppointmentDialog extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback onSaved;

  const _EditAppointmentDialog({
    required this.appointment,
    required this.onSaved,
  });

  @override
  State<_EditAppointmentDialog> createState() => _EditAppointmentDialogState();
}

class _EditAppointmentDialogState extends State<_EditAppointmentDialog> {
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _serviceController;
  late TextEditingController _barberController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.appointment.date);
    _timeController = TextEditingController(text: widget.appointment.time.split(' - ').first);
    _serviceController = TextEditingController(text: widget.appointment.serviceName);
    _barberController = TextEditingController(text: widget.appointment.barberName);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _serviceController.dispose();
    _barberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Editar Turno', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Fecha (Ej: 4 de Julio de 2026)', _dateController),
              const SizedBox(height: 12),
              _buildField('Hora (Ej: 09:00)', _timeController),
              const SizedBox(height: 12),
              _buildField('Servicio', _serviceController),
              const SizedBox(height: 12),
              _buildField('Barbero', _barberController),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final adminProvider = context.read<AdminProvider>();
      final startTime = _timeController.text.trim();

      final isBooked = await adminProvider.checkAvailabilityExcluding(
        _dateController.text.trim(),
        widget.appointment.barberId,
        startTime,
        excludeId: widget.appointment.id,
      );

      if (isBooked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El horario ya se encuentra ocupado.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final timeStr = '$startTime - ${_calcEndTime(startTime)}';
      await adminProvider.updateAppointment(widget.appointment.id, {
        'date': _dateController.text.trim(),
        'time': timeStr,
        'startTime': startTime,
        'serviceName': _serviceController.text.trim(),
        'barberName': _barberController.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno actualizado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _calcEndTime(String start) {
    final parts = start.split(':');
    int hr = int.parse(parts[0]);
    int min = int.parse(parts[1]) + 30;
    if (min >= 60) {
      hr += 1;
      min -= 60;
    }
    return '${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
}
