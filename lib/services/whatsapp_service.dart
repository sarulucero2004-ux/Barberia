import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/appointment.dart';

class WhatsAppService {
  Future<void> sendBookingMessage(Appointment appointment) async {
    final message = '''
💈 *NUEVO TURNO*

👤 Cliente: ${appointment.customerName}
✂ Servicio: ${appointment.serviceName}
📅 Fecha: ${appointment.date}
⏰ Hora: ${appointment.time}
🧔 Barbero: ${appointment.barberName}
💲 Precio: \$${appointment.servicePrice.toStringAsFixed(0)}
''';

    final encodedMessage = Uri.encodeComponent(message);
    final phone = appointment.barberPhone.replaceAll(RegExp(r'\D'), '');

    final url = Uri.parse("https://wa.me/$phone?text=$encodedMessage");

    try {
      final canOpen = await canLaunchUrl(url);
      if (canOpen) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
    }
  }
}
