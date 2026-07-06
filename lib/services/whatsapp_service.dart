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
    final phone = appointment.barberPhone;

    final url = Uri.parse("https://wa.me/$phone?text=$encodedMessage");

    try {
      final canOpen = await canLaunchUrl(url);
      if (!canOpen) {
        throw Exception(
          'No se pudo abrir WhatsApp. '
          'Copia este mensaje manualmente:\n\n$message',
        );
      }
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al abrir WhatsApp.');
    }
  }
}
