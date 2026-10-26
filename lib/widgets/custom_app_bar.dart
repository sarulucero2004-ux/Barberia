import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/admin_panel.dart';
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
  Size get preferredSize => const Size.fromHeight(116.0);

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF090909), Colors.black],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x33D4AF37), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                            if (authProvider.isAdmin) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.admin_panel_settings, size: 18),
                                label: const Text('Panel Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _openAdminPanel(context),
                              ),
                              const SizedBox(width: 12),
                            ],
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (authProvider.isLoggedIn && authProvider.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFD4AF37)),
                          onPressed: () => _openAdminPanel(context),
                          tooltip: 'Panel Admin',
                        ),
                      IconButton(
                        icon: Icon(
                          authProvider.isLoggedIn ? Icons.logout : Icons.login,
                          color: const Color(0xFFD4AF37),
                        ),
                        onPressed: authProvider.isLoggedIn
                            ? () => authProvider.logout()
                            : () => _navigateToLogin(context),
                        tooltip: authProvider.isLoggedIn
                            ? 'Cerrar sesión'
                            : 'Iniciar sesión',
                      ),
                    ],
                  ),
              ],
            ),
            if (isMobile)
              SizedBox(
                height: 36,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _navLink('Inicio', () => _scrollToSection(0), compact: true),
                      _navLink('Barberos', () => _scrollToSection(heroHeight), compact: true),
                      _navLink('Servicios', () => _scrollToSection(heroHeight + aboutUsHeight), compact: true),
                      _navLink('Reservar', () => _scrollToSection(heroHeight + aboutUsHeight + servicesHeight), compact: true),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap, {bool compact = false}) {
    return _NavLink(
      label: label,
      compact: compact,
      onTap: onTap,
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _openAdminPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPanel()),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFD4AF37);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 3 : 4),
      child: Tooltip(
        message: widget.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onHover: (hovering) {
              if (_isHovered != hovering) {
                setState(() => _isHovered = hovering);
              }
            },
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 9 : 11,
                vertical: widget.compact ? 6 : 9,
              ),
              decoration: BoxDecoration(
                color: _isHovered
                    ? gold.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  bottom: BorderSide(
                    color: _isHovered ? gold : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: _isHovered ? const Color(0xFFE5C65A) : Colors.white70,
                  fontSize: widget.compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: widget.compact ? 0.8 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
