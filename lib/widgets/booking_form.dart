import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/service.dart';
import '../models/time_slot.dart';

import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/whatsapp_service.dart';

import 'login_modal.dart';

class BookingForm extends StatefulWidget {
  final List<Barber> barbers;
  final List<Service> services;

  const BookingForm({
    super.key,
    required this.barbers,
    required this.services,
  });

  @override
  State<BookingForm> createState() => _BookingFormState();
}


class _BookingFormState extends State<BookingForm> {
  final _formKey = GlobalKey<FormState>();

  Service? _selectedService;
  Barber? _selectedBarber;

  List<Service> _dynamicServices = [];

  late List<DateTime> _dates;
  late DateTime _selectedDate;
  TimeSlot? _selectedTimeSlot;

  final ScrollController _carouselScrollController = ScrollController();
  final ScrollController _timeScrollController = ScrollController();

  final List<String> _weekdaysShort = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  final List<String> _weekdaysFull = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];
  final List<String> _monthsShort = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];
  final List<String> _monthsFull = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _dynamicServices = widget.services;

    if (_dynamicServices.isNotEmpty) {
      _selectedService = _dynamicServices.first;
    }
    if (widget.barbers.isNotEmpty) {
      _selectedBarber = widget.barbers.first;
    }

    _dates = List.generate(14, (index) => DateTime.now().add(Duration(days: index)));
    _selectedDate = _dates.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookedTimesForCurrentSelection();
    });
  }

  @override
  void didUpdateWidget(covariant BookingForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.services != oldWidget.services) {
      // Cada emisión del stream de Firestore crea instancias nuevas de Service
      // (Service no define ==, compara por identidad). Si se conservara la
      // instancia anterior el Dropdown apuntaría a un objeto que ya no está en
      // la lista y se dispararía el assert de dropdown.dart; además arrastraría
      // el nombre y el precio previos a la edición. Por eso la selección se
      // re-resuelve siempre por `id`.
      _dynamicServices = widget.services;
      if (widget.services.isEmpty) {
        _selectedService = null;
      } else {
        final currentId = _selectedService?.id;
        final matches = currentId == null
            ? <Service>[]
            : widget.services.where((Service s) => s.id == currentId).toList();
        _selectedService = matches.isNotEmpty ? matches.first : widget.services.first;
      }
    }
    if (widget.barbers != oldWidget.barbers) {
      // Cada emisión del stream de Firestore crea instancias nuevas de Barber
      // (Barber no define ==, compara por identidad). Si se conservara la
      // instancia anterior el Dropdown quedaría apuntando a un objeto que ya no
      // está en la lista y se dispararía el assert de dropdown.dart.
      // Por eso la selección se re-resuelve siempre por `id`.
      if (widget.barbers.isEmpty) {
        _selectedBarber = null;
      } else {
        final currentId = _selectedBarber?.id;
        final matches = currentId == null
            ? <Barber>[]
            : widget.barbers.where((b) => b.id == currentId).toList();
        _selectedBarber = matches.isNotEmpty ? matches.first : widget.barbers.first;
      }
    }
  }

  @override
  void dispose() {
    _carouselScrollController.dispose();
    _timeScrollController.dispose();
    super.dispose();
  }

  /// Genera los horarios de atención del día desde `config/negocio`.
  ///
  /// Los horarios vienen de Firestore: ya no hay lista fija en el código. Si la
  /// configuración no se pudo leer devuelve una lista vacía y el estado de
  /// error se muestra aparte, de modo que nunca se interprete como "no hay
  /// horarios" ni como "todos están libres".
  List<TimeSlot> _getTimeSlotsForDate(DateTime date) {
    final schedule = context.read<BookingProvider>().schedule;
    if (schedule == null) return const [];

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    // El paso de generación y la duración mostrada salen de `slotMinutos`
    // (30 en la configuración actual). No se usa `servicio.duracion`.
    final step = schedule.slotMinutos;
    final availableHours = schedule
        .getSlotsForWeekday(date.weekday)
        .where((start) {
      if (!isToday) return true;
      final parts = start.split(':');
      final hr = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      final slotTime = DateTime(now.year, now.month, now.day, hr, min);
      return slotTime.isAfter(now);
    }).toList();

    return availableHours.map((start) {
      final parts = start.split(':');
      int hr = int.parse(parts[0]);
      int min = int.parse(parts[1]) + step;
      if (min >= 60) {
        hr += 1;
        min -= 60;
      }
      final end = "${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";

      return TimeSlot(
        startTime: start,
        endTime: end,
        isAvailable: true,
      );
    }).toList();
  }

  void _scrollCarousel(bool goRight) {
    final double offset = goRight
        ? _carouselScrollController.offset + 120
        : _carouselScrollController.offset - 120;
    _carouselScrollController.animateTo(
      offset.clamp(0.0, _carouselScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _loadBookedTimesForCurrentSelection() {
    if (_selectedBarber == null) return;
    final formattedDate = "${_selectedDate.day} de ${_monthsFull[_selectedDate.month - 1]} de ${_selectedDate.year}";
    // La selección de horario nunca sobrevive a un cambio de barbero/fecha ni a
    // un reintento: un slot elegido con una disponibilidad distinta debe quedar
    // sin seleccionar para que no se pueda confirmar un turno no verificado.
    _selectedTimeSlot = null;
    context.read<BookingProvider>().loadBookedTimes(formattedDate, _selectedBarber!.id);
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedTimeSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona un turno disponible en la lista.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isLoggedIn) {
        _showLoginRequiredModal();
      } else {
        _processBooking();
      }
    }
  }

  void _showLoginRequiredModal() {
    showDialog(
      context: context,
      builder: (context) => LoginModal(
        onLoginSuccess: () {
          _processBooking();
        },
      ),
    );
  }

  void _processBooking() async {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    final formattedDate = "${_selectedDate.day} de ${_monthsFull[_selectedDate.month - 1]} de ${_selectedDate.year}";
    final formattedTime = "${_selectedTimeSlot!.startTime} - ${_selectedTimeSlot!.endTime}";
    final customerName = authProvider.nombreCompleto.trim().isNotEmpty
        ? authProvider.nombreCompleto
        : authProvider.email;

    try {
      await bookingProvider.confirmBooking(
        userId: authProvider.uid,
        customerName: customerName,
        customerEmail: authProvider.email,
        barber: _selectedBarber!,
        service: _selectedService!,
        date: formattedDate,
        time: formattedTime,
      );

      if (!mounted) return;

      _loadBookedTimesForCurrentSelection();

      final appointmentToNotify = Appointment(
        id: '',
        userId: authProvider.uid,
        customerName: customerName,
        customerEmail: authProvider.email,
        barberId: _selectedBarber!.id,
        barberName: _selectedBarber!.name,
        barberPhone: _selectedBarber!.phone,
        serviceId: _selectedService!.id,
        serviceName: _selectedService!.name,
        servicePrice: _selectedService!.price,
        date: formattedDate,
        time: formattedTime,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFFD4AF37)),
              SizedBox(width: 12),
              Text(
                '¡Turno Reservado!',
                style: TextStyle(color: Colors.white, fontFamily: 'Playfair Display'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente: $customerName', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Servicio: ${_selectedService?.name}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Barbero: ${_selectedBarber?.name}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Fecha: $formattedDate', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Horario: $formattedTime hs', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text(
                'Presioná "NOTIFICAR POR WHATSAPP" para avisarle a tu barbero.',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('NOTIFICAR POR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                WhatsAppService().sendBookingMessage(appointmentToNotify);
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedTimeSlot = null;
                });
              },
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 768;
    final authProvider = context.watch<AuthProvider>();

    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 64.0,
        vertical: 80.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 20.0 : 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'RESERVA TU ESPACIO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    letterSpacing: 3,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PROGRAMAR UN TURNO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona tus preferencias y reserva al instante.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const Divider(color: Colors.white10, height: 40),

                isMobile
                    ? Column(
                        children: [
                          _buildServiceDropdown(),
                          const SizedBox(height: 20),
                          _buildBarberDropdown(),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildServiceDropdown()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildBarberDropdown()),
                        ],
                      ),

                const SizedBox(height: 32),

                const Text(
                  'SELECCIONA FECHA Y HORA',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                _buildDateNavigator(),
                const SizedBox(height: 12),
                _buildDayHeader(),
                const SizedBox(height: 12),
                _buildTimeSlotList(),

                const SizedBox(height: 32),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 6,
                  ),
                  onPressed: _handleSubmit,
                  child: Text(
                    authProvider.isLoggedIn
                        ? 'CONFIRMAR RESERVA'
                        : 'INICIAR SESIÓN Y RESERVAR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
          onPressed: () => _scrollCarousel(false),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 72,
            child: ListView.builder(
              controller: _carouselScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final dayName = _weekdaysShort[date.weekday % 7];
                final dayNum = date.day.toString();
                final monthName = _monthsShort[date.month - 1];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null;
                    });
                    _loadBookedTimesForCurrentSelection();
                  },
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0D47A1).withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$dayName $dayNum",
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          monthName.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
          onPressed: () => _scrollCarousel(true),
        ),
      ],
    );
  }

  Widget _buildDayHeader() {
    final weekdayName = _weekdaysFull[_selectedDate.weekday % 7];
    final monthName = _monthsFull[_selectedDate.month - 1];
    final dateText = "$weekdayName ${_selectedDate.day} de $monthName";

    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            dateText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Estado informativo de la disponibilidad: reemplaza la lista de horarios
  /// cuando todavía no se puede afirmar qué horarios están libres.
  Widget _buildAvailabilityMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white38, size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
                side: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlotList() {
    final bookingProvider = context.watch<BookingProvider>();
    final slots = _getTimeSlotsForDate(_selectedDate);

    // Sin `config/negocio` no se sabe qué horarios existen, así que no se
    // calcula la lista todavía: primero se resuelve el estado de la
    // configuración. No hay lista hardcodeada de respaldo, para que un fallo de
    // Firestore no termine mostrando todos los horarios como disponibles.
    if (bookingProvider.scheduleError) {
      return _buildAvailabilityMessage(
        icon: Icons.cloud_off,
        message:
            'No se pudieron cargar los horarios de atención.\nRevisá tu conexión e intentá de nuevo.',
        actionLabel: 'Reintentar',
        onAction: bookingProvider.retrySchedule,
      );
    }

    if (!bookingProvider.scheduleLoaded) {
      return _buildAvailabilityMessage(
        icon: Icons.hourglass_empty,
        message: 'Cargando horarios...',
      );
    }

    // No se ofrece ningún horario hasta tener una respuesta verificable:
    // "en vuelo" y "falló" no significan "disponible". Se mantiene el mismo
    // contenedor visual, solo cambia el contenido, y nunca hay pantalla roja.
    if (bookingProvider.availabilityError) {
      return _buildAvailabilityMessage(
        icon: Icons.cloud_off,
        message:
            'No se pudo verificar la disponibilidad.\nRevisá tu conexión e intentá de nuevo.',
        actionLabel: 'Reintentar',
        onAction: _loadBookedTimesForCurrentSelection,
      );
    }

    if (!bookingProvider.availabilityLoaded) {
      return _buildAvailabilityMessage(
        icon: Icons.hourglass_empty,
        message: 'Verificando disponibilidad...',
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: RawScrollbar(
        controller: _timeScrollController,
        thumbColor: const Color(0xFFD4AF37),
        radius: const Radius.circular(8),
        thickness: 6,
        thumbVisibility: true,
        trackVisibility: true,
        trackColor: Colors.white10,
        child: ListView.builder(
          controller: _timeScrollController,
          itemCount: slots.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isBooked = bookingProvider.bookedTimes.contains(slot.startTime);
            final isSelected = _selectedTimeSlot != null &&
                _selectedTimeSlot!.startTime == slot.startTime;

            if (!isBooked) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                      width: isSelected ? 3.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.startTime,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slot.endTime,
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            'DISPONIBLE',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '30 m',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            } else {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.startTime,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slot.endTime,
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        Text(
                          'RESERVADO',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.info, color: Colors.red, size: 20),
                      ],
                    )
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildServiceDropdown() {
    // Se identifica al servicio por su `id` de documento en lugar de por la
    // identidad de instancia del objeto Service, que cambia en cada emisión del
    // stream de Firestore. Con `value` por instancia, el assert de
    // dropdown.dart:1830 ("There should be exactly one item with value") se
    // dispara al volver del panel de administración, porque el guard de
    // didUpdateWidget conservaba la instancia anterior.
    return DropdownButtonFormField<String>(
      value: _selectedService?.id,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Selecciona Servicio', Icons.content_cut),
      items: _dynamicServices.map((Service service) {
        return DropdownMenuItem<String>(
          value: service.id,
          child: Text('${service.name} (\$${service.price.toStringAsFixed(0)})'),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value == null) return;
        final Service? selected = _dynamicServices
            .where((Service service) => service.id == value)
            .firstOrNull;
        if (selected == null) return;
        setState(() {
          _selectedService = selected;
        });
      },
    );
  }

  Widget _buildBarberDropdown() {
    // Se identifica al barbero por su `id` de documento (B1, B2, ...) en lugar
    // de por la identidad de instancia del objeto Barber, que cambia en cada
    // emisión del stream de Firestore.
    return DropdownButtonFormField<String>(
      value: _selectedBarber?.id,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Selecciona Barbero', Icons.person_outline),
      items: widget.barbers.map((Barber barber) {
        return DropdownMenuItem<String>(
          value: barber.id,
          child: Text(barber.name),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value == null) return;
        final Barber? selected = widget.barbers
            .where((Barber barber) => barber.id == value)
            .firstOrNull;
        if (selected == null) return;
        setState(() {
          _selectedBarber = selected;
        });
        _loadBookedTimesForCurrentSelection();
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
    );
  }
}
