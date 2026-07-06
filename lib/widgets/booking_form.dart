import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/barber.dart';
import '../models/service.dart';
import '../models/time_slot.dart';

import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';

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
  void dispose() {
    _carouselScrollController.dispose();
    _timeScrollController.dispose();
    super.dispose();
  }

  List<TimeSlot> _getTimeSlotsForDate(DateTime date) {
    final List<String> hours = [
      '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
      '12:00', '12:30', '13:00', '13:30', '16:00', '16:30',
      '17:00', '17:30', '18:00', '18:30', '19:00', '19:30'
    ];

    return List.generate(hours.length, (index) {
      final start = hours[index];
      final parts = start.split(':');
      int hr = int.parse(parts[0]);
      int min = int.parse(parts[1]) + 30;
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
    });
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

    try {
      await bookingProvider.confirmBooking(
        userId: authProvider.uid,
        customerName: authProvider.nombreCompleto.isNotEmpty
            ? authProvider.nombreCompleto
            : authProvider.email,
        customerEmail: authProvider.email,
        barber: _selectedBarber!,
        service: _selectedService!,
        date: formattedDate,
        time: formattedTime,
      );

      if (!mounted) return;

      _loadBookedTimesForCurrentSelection();

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
              Text('Cliente: $formattedDate', style: const TextStyle(color: Colors.white70)),
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
                'Al presionar ENTENDIDO serás redirigido a WhatsApp para notificar a tu barbero.',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
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

  Widget _buildTimeSlotList() {
    final bookingProvider = context.watch<BookingProvider>();
    final slots = _getTimeSlotsForDate(_selectedDate);

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
    return DropdownButtonFormField<Service>(
      value: _selectedService,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Selecciona Servicio', Icons.content_cut),
      items: _dynamicServices.map((Service service) {
        return DropdownMenuItem<Service>(
          value: service,
          child: Text('${service.name} (\$${service.price.toStringAsFixed(0)})'),
        );
      }).toList(),
      onChanged: (Service? value) {
        setState(() {
          _selectedService = value;
        });
      },
    );
  }

  Widget _buildBarberDropdown() {
    return DropdownButtonFormField<Barber>(
      value: _selectedBarber,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Selecciona Barbero', Icons.person_outline),
      items: widget.barbers.map((Barber barber) {
        return DropdownMenuItem<Barber>(
          value: barber,
          child: Text(barber.name),
        );
      }).toList(),
      onChanged: (Barber? value) {
        setState(() {
          _selectedBarber = value;
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
