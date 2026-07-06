import 'package:flutter/material.dart';

class HeroSection extends StatelessWidget {
  final VoidCallback onReservePressed;

  const HeroSection({
    Key? key,
    required this.onReservePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 768;

    return Container(
      height: isMobile ? 500 : 700,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: AssetImage('assets/images/hero_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.35, // Atenuar la imagen para ver bien el texto
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.9),
              Colors.black,
            ],
            stops: const [0.0, 0.8, 1.0],
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24.0 : 64.0,
          vertical: 40.0,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ESTILO Y MODERNIDAD',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      letterSpacing: 3,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cortes de cabello, Diseños y color',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: isMobile ? 36 : 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: isMobile ? TextAlign.center : TextAlign.left,
                ),
                const SizedBox(height: 16),
                Text(
                  'Un espacio diseñado exclusivamente para el hombre moderno. Vive una experiencia premium en el cuidado de tu imagen con los mejores profesionales del sector.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 14 : 18,
                    height: 1.6,
                  ),
                  textAlign: isMobile ? TextAlign.center : TextAlign.left,
                ),
                const SizedBox(height: 36),
                // Botón con animación o efectos al interactuar
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 32 : 48,
                      vertical: isMobile ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFFD4AF37).withOpacity(0.4),
                  ),
                  onPressed: onReservePressed,
                  child: Text(
                    'RESERVAR TURNO',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
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
}
