import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ScrollController scrollController;
  final double heroHeight;
  final double aboutUsHeight;
  final double servicesHeight;

  const CustomAppBar({
    super.key,
    required this.scrollController,
    required this.heroHeight,
    required this.aboutUsHeight,
    required this.servicesHeight,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80.0);

  void _scrollToSection(double offset) {
    scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final authProvider = context.watch<AuthProvider>();

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(width: 12),
                Text(
                  'DOUBLE EDGE',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            if (!isMobile)
              Row(
                children: [
                  _navLink('Inicio', () => _scrollToSection(0)),
                  _navLink('Barberos', () => _scrollToSection(heroHeight)),
                  _navLink('Servicios', () => _scrollToSection(heroHeight + aboutUsHeight)),
                  _navLink('Reservar', () => _scrollToSection(heroHeight + aboutUsHeight + servicesHeight)),
                  const SizedBox(width: 24),
                  if (authProvider.isLoggedIn)
                    Row(
                      children: [
                        Text(
                          'Hola, ${authProvider.nombre}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            foregroundColor: const Color(0xFFD4AF37),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => authProvider.logout(),
                          child: const Text('Salir'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () => _navigateToLogin(context),
                      child: const Text(
                        'INICIAR SESIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              )
            else
              authProvider.isLoggedIn
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.logout, color: Color(0xFFD4AF37)),
                          onPressed: () => authProvider.logout(),
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.login, color: Color(0xFFD4AF37)),
                      onPressed: () => _navigateToLogin(context),
                      tooltip: 'Iniciar sesión',
                    ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }
}
