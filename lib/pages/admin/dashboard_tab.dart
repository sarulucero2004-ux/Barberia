import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/appointment_status.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late String _todayDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    _todayDate = '${now.day} de ${months[now.month - 1]} de ${now.year}';
  }

  void _refresh() {
    context.read<AdminProvider>().loadDashboardStats(_todayDate);
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumen del $_todayDate',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (adminProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(adminProvider),
                  const SizedBox(height: 32),
                  _buildNextAppointment(adminProvider),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AdminProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              'Turnos Hoy',
              '${provider.todayCount}',
              Icons.today,
              const Color(0xFF2196F3),
            ),
            _buildStatCard(
              'Pendientes',
              '${provider.pendingCount}',
              Icons.pending_actions,
              const Color(0xFFFF9800),
            ),
            _buildStatCard(
              'Confirmados',
              '${provider.confirmedCount}',
              Icons.check_circle,
              const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              'Cancelados',
              '${provider.cancelledCount}',
              Icons.cancel,
              const Color(0xFFF44336),
            ),
            _buildStatCard(
              'Finalizados',
              '${provider.completedCount}',
              Icons.done_all,
              const Color(0xFF9C27B0),
            ),
            _buildStatCard(
              'Total Clientes',
              '${provider.totalClients}',
              Icons.people,
              const Color(0xFF009688),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextAppointment(AdminProvider provider) {
    final next = provider.nextAppointment;
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.white38, size: 24),
            SizedBox(width: 16),
            Text(
              'No hay próximos turnos para hoy.',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final statusStr = next['status'] ?? 'pending';
    final status = AppointmentStatus.fromString(statusStr);
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Color(0xFFD4AF37), size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'PRÓXIMO TURNO',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _infoColumn('Cliente', next['customerName'] ?? ''),
              const SizedBox(width: 40),
              _infoColumn('Servicio', next['serviceName'] ?? ''),
              const SizedBox(width: 40),
              _infoColumn('Barbero', next['barberName'] ?? ''),
              const SizedBox(width: 40),
              _infoColumn('Hora', next['time'] ?? ''),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
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
