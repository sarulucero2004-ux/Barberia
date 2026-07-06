import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/service.dart';
import '../widgets/about_us_section.dart';
import '../widgets/booking_form.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/hero_section.dart';
import '../widgets/services_section.dart';

class HomeScreen extends StatefulWidget {
  final bool firebaseInitialized;

  const HomeScreen({super.key, required this.firebaseInitialized});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<Barber> _barbers = [
    Barber(
      id: 'b1',
      name: 'Ezequiel',
      imageUrl: 'assets/images/barber_ezequiel.png',
      specialty: 'Cortes clásicos, degradados & afeitados tradicionales',
      rating: 4.9,
      phone: '5491141948792',
    ),
    Barber(
      id: 'b2',
      name: 'Isaías',
      imageUrl: 'assets/images/barber_isaias.png',
      specialty: 'Diseño de barba, perfilados & peinados vintage',
      rating: 4.8,
      phone: '5491134855509',
    ),
  ];

  final List<Service> _services = [
    Service(
      id: 's1',
      name: 'Corte de cabello',
      description: 'Corte personalizado con lavado, masaje capilar y peinado con cera premium.',
      price: 9000,
      durationMinutes: 30,
    ),
    Service(
      id: 's2',
      name: 'corte de barba',
      description: 'Afeitado tradicional a navaja con toallas calientes y bálsamo hidratante.',
      price: 2000,
      durationMinutes: 20,
    ),
    Service(
      id: 's3',
      name: 'Perfilado de cejas',
      description: 'Esculpido, rebaje y alineación de contornos con navaja e hidratación.',
      price: 1500,
      durationMinutes: 10,
    ),
    Service(
      id: 's4',
      name: 'Global',
      description: 'El servicio definitivo: Corte premium + Perfilado de barba con toallas calientes.',
      price: 30000,
      durationMinutes: 60,
    ),
  ];

  final double _heroHeight = 650.0;
  final double _aboutUsHeight = 850.0;
  final double _servicesHeight = 700.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBooking() {
    final offset = _heroHeight + _aboutUsHeight + _servicesHeight;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        scrollController: _scrollController,
        heroHeight: _heroHeight,
        aboutUsHeight: _aboutUsHeight,
        servicesHeight: _servicesHeight,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            if (!widget.firebaseInitialized)
              Container(
                color: Colors.amber[900],
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modo de Demostración: Firebase local no inicializado. '
                        'Por favor corre "flutterfire configure" para conectarlo a tu base de datos.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            HeroSection(onReservePressed: _scrollToBooking),
            AboutUsSection(barbers: _barbers),
            ServicesSection(services: _services),
            BookingForm(
              barbers: _barbers,
              services: _services,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      width: double.infinity,
      child: Column(
        children: [
          const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 36),
          const SizedBox(height: 16),
          const Text(
            'DOUBLE EDGE BARBERSHOP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          const Text(
            '© 2026 Double Edge. Todos los derechos reservados.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lunes a Sábado: 09:00 - 21:00 hs y Domingos 10:00 - 13:30 hs',
            style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
