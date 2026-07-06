import 'package:flutter/material.dart';
import '../models/barber.dart';

class AboutUsSection extends StatelessWidget {
  final List<Barber> barbers;

  const AboutUsSection({
    Key? key,
    required this.barbers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 768;

    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 64.0,
        vertical: 80.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'QUIÉNES SOMOS',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  letterSpacing: 3,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'LOS AMIGOS',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 3,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 24),
              const Text(
                'EN NUESTRO ESPACIO NOS GUSTA CONECTARNOS CON NUESTROS CLIENTES, NO ES SOLO UN ESPACIO PARA TRABAJO, SINO PARA HACER AMISTADES YA SEAN NIÑOS, ADOLESCENTES O ADULTOS. ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              // Grid/Column of Barbers
              isMobile
                  ? Column(
                      children: barbers.map((barber) => _buildBarberCard(barber, true)).toList(),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: barbers.map((barber) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildBarberCard(barber, false),
                            ),
                          )).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarberCard(Barber barber, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 32.0 : 0.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del Barbero
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              barber.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, size: 64, color: Colors.white54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  barber.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  barber.specialty,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      barber.rating.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ 5.0 (Reseñas)',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
