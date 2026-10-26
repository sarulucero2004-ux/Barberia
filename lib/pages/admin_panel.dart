import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import 'admin/appointments_tab.dart';
import 'admin/agenda_tab.dart';
import 'admin/services_tab.dart';
import 'admin/barbers_tab.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Turnos',
    'Agenda',
    'Servicios',
    'Barberos',
  ];

  static const List<IconData> _icons = [
    Icons.calendar_today,
    Icons.schedule,
    Icons.content_cut,
    Icons.people,
  ];

  final List<Widget> _pages = const [
    AppointmentsTab(),
    AgendaTab(),
    ServicesTab(),
    BarbersTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isCompact = MediaQuery.of(context).size.width < 900;

    if (!authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(firebaseInitialized: true),
          ),
        );
      });
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          if (!isCompact) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isCompact),
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isCompact ? _buildDrawer() : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'GOLDEN\nSCISSORS',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            ...List.generate(
              _titles.length,
              (index) => ListTile(
                leading: Icon(
                  _icons[index],
                  color: _selectedIndex == index
                      ? const Color(0xFFD4AF37)
                      : Colors.white54,
                ),
                title: Text(
                  _titles[index],
                  style: TextStyle(
                    color: _selectedIndex == index
                        ? const Color(0xFFD4AF37)
                        : Colors.white70,
                    fontWeight: _selectedIndex == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: _selectedIndex == index,
                onTap: () {
                  setState(() => _selectedIndex = index);
                  _scaffoldKey.currentState?.closeDrawer();
                },
              ),
            ),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white54),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'GOLDEN\nSCISSORS',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          ...List.generate(_titles.length, (index) {
            final isSelected = _selectedIndex == index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? const Border(
                        left: BorderSide(color: Color(0xFFD4AF37), width: 3),
                      )
                    : null,
              ),
              child: ListTile(
                leading: Icon(
                  _icons[index],
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
                  size: 22,
                ),
                title: Text(
                  _titles[index],
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                dense: true,
              ),
            );
          }),
          const Spacer(),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white54, size: 22),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            onTap: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(firebaseInitialized: true),
                ),
              );
            },
            dense: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isCompact) {
    final authProvider = context.watch<AuthProvider>();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (isCompact)
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFFD4AF37)),
                    tooltip: 'Abrir menú',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                if (isCompact) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _titles[_selectedIndex],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: isCompact ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.admin_panel_settings, color: Color(0xFFD4AF37), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Admin: ${authProvider.nombreCompleto}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(firebaseInitialized: true),
      ),
    );
  }
}
