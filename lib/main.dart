import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/booking_service.dart';
import 'services/whatsapp_service.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Error al inicializar Firebase: $e');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final whatsAppService = WhatsAppService();
    final bookingService = BookingService(
      firestoreService: firestoreService,
      whatsAppService: whatsAppService,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService: authService,
            firestoreService: firestoreService,
          ),
        ),
        ChangeNotifierProvider<BookingProvider>(
          create: (_) => BookingProvider(
            bookingService: bookingService,
            firestoreService: firestoreService,
          ),
        ),
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => AdminProvider(
            firestoreService: firestoreService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Golden Scissors | Barbería Premium',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          primaryColor: const Color(0xFFD4AF37),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4AF37),
            secondary: Colors.white,
            surface: Color(0xFF121212),
            onSurface: Colors.white,
          ),
          fontFamily: 'Montserrat',
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Playfair Display', color: Colors.white),
            titleLarge: TextStyle(fontFamily: 'Playfair Display', color: Colors.white),
          ),
        ),
        home: HomeScreen(firebaseInitialized: firebaseInitialized),
      ),
    );
  }
}
