import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../models/barber.dart';

class BarbersTab extends StatefulWidget {
  const BarbersTab({super.key});

  @override
  State<BarbersTab> createState() => _BarbersTabState();
}

class _BarbersTabState extends State<BarbersTab> {
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.read<AdminProvider>();
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: EdgeInsets.all(isCompact ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BARBEROS',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Agregar Barbero',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showBarberDialog(context, null),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BARBEROS',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Agregar Barbero',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showBarberDialog(context, null),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminProvider.getBarbersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay barberos registrados.',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  );
                }

                final barbers = docs.map((doc) {
                  return Barber.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                }).toList();

                return ListView.builder(
                  itemCount: barbers.length,
                  itemBuilder: (context, index) {
                    final barber = barbers[index];
                    return _BarberCard(
                      barber: barber,
                      onEdit: () => _showBarberDialog(context, barber),
                      onDelete: () => _confirmDelete(context, barber),
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

  void _showBarberDialog(BuildContext context, Barber? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _BarberFormDialog(
        barber: existing,
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Barber barber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eliminar Barbero', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de eliminar a "${barber.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performDelete(context, barber);
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFF44336))),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(BuildContext context, Barber barber) async {
    try {
      await context.read<AdminProvider>().deleteBarber(barber.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${barber.name}" eliminado correctamente.'),
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
}

class _BarberCard extends StatelessWidget {
  final Barber barber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BarberCard({
    required this.barber,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final image = ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: barber.imageUrl == null
            ? _barberPlaceholder()
            : Image.asset(
                barber.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _barberPlaceholder(),
              ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          barber.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          barber.specialty,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        if (!barber.activo) ...[
          const SizedBox(height: 6),
          const Text(
            'Inactivo',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ],
        if (isCompact) ...[
          const SizedBox(height: 4),
          Text(
            barber.phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF2196F3), size: 20),
          onPressed: onEdit,
          tooltip: 'Editar',
          visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Color(0xFFF44336), size: 20),
          onPressed: onDelete,
          tooltip: 'Eliminar',
          visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
        ),
      ],
    );

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      image,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                children: [
                  image,
                  const SizedBox(width: 20),
                  Expanded(child: details),
                  const SizedBox(width: 24),
                  Text(
                    barber.phone,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
      ),
    );
  }

  Widget _barberPlaceholder() {
    return Container(
      color: Colors.white12,
      child: const Icon(Icons.person, color: Colors.white54, size: 28),
    );
  }
}

class _BarberFormDialog extends StatefulWidget {
  final Barber? barber;
  final VoidCallback onSaved;

  const _BarberFormDialog({this.barber, required this.onSaved});

  @override
  State<_BarberFormDialog> createState() => _BarberFormDialogState();
}

class _BarberFormDialogState extends State<_BarberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _specialtyCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.barber?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.barber?.phone ?? '');
    _specialtyCtrl = TextEditingController(text: widget.barber?.specialty ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  bool get isEditing => widget.barber != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        isEditing ? 'Editar Barbero' : 'Agregar Barbero',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 480
            ? MediaQuery.of(context).size.width * 0.82
            : 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Teléfono (Ej: 5491141948792)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialtyCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Especialidad'),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ],
            ),
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
              : Text(
                  isEditing ? 'Guardar' : 'Agregar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
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
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<AdminProvider>();
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
      final specialty = _specialtyCtrl.text.trim();

      if (isEditing) {
        await provider.updateBarber(widget.barber!.id, name, phone, specialty);
      } else {
        await provider.addBarber(name, phone, specialty);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Barbero actualizado.' : 'Barbero agregado.'),
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
}
