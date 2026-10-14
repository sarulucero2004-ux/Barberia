import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/appointment.dart';

class WhatsAppResult {
  final bool success;
  final String message;

  const WhatsAppResult({
    required this.success,
    required this.message,
  });

  factory WhatsAppResult.opened() => const WhatsAppResult(
        success: true,
        message:
            'Se abrió WhatsApp con el mensaje preparado. Presioná "Enviar" en WhatsApp para avisarle al barbero.',
      );

  factory WhatsAppResult.error(String message) => WhatsAppResult(
        success: false,
        message: message,
      );
}

class WhatsAppService {
  /// Valida y normaliza un número de teléfono para WhatsApp.
  /// Contempla el formato de números argentinos (con o sin prefijo 54/549,
  /// con o sin 0 inicial, con o sin 15 móvil) y números internacionales
  /// explícitos con prefijo '+'.
  /// Retorna el número sanitizado en formato E.164 (sin '+') o `null` si no es válido.
  String? formatPhoneForWhatsApp(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return null;
    }

    final trimmed = rawPhone.trim();
    final hasPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return null;
    }

    // Prefijo internacional de marcado directo 00 (ej: 0054...)
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Caso 1: Comienza con prefijo de Argentina (54)
    if (digits.startsWith('54')) {
      var without54 = digits.substring(2);
      if (without54.startsWith('9')) {
        without54 = without54.substring(1);
      }
      if (without54.startsWith('0')) {
        without54 = without54.substring(1);
      }
      without54 = _stripArgentine15(without54);

      // Un número nacional argentino válido tiene exactamente 10 dígitos (código de área + abonado)
      if (without54.length == 10) {
        return '549$without54';
      }
      return null;
    }

    // Caso 2: Número con '+' explícito de otro país (ej: +1..., +598...)
    if (hasPlus) {
      // Formato internacional estándar E.164: entre 10 y 15 dígitos
      if (digits.length >= 10 && digits.length <= 15) {
        return digits;
      }
      return null;
    }

    // Caso 3: Número local argentino (sin código de país 54)
    var local = digits;
    if (local.startsWith('0')) {
      local = local.substring(1);
    }
    local = _stripArgentine15(local);

    if (local.length == 10) {
      return '549$local';
    }

    // No se pudo determinar con seguridad un formato válido
    return null;
  }

  /// Remueve el prefijo móvil '15' si está después del código de área (2, 3 o 4 dígitos)
  /// y el resultado resultante tiene 10 dígitos.
  String _stripArgentine15(String num) {
    if (num.length == 12) {
      // 2 dígitos de área (ej: 11 15 XXXXXXXX)
      if (num.substring(2, 4) == '15') {
        return num.substring(0, 2) + num.substring(4);
      }
      // 3 dígitos de área (ej: 351 15 XXXXXXX)
      if (num.substring(3, 5) == '15') {
        return num.substring(0, 3) + num.substring(5);
      }
      // 4 dígitos de área (ej: 2202 15 XXXXXX)
      if (num.substring(4, 6) == '15') {
        return num.substring(0, 4) + num.substring(6);
      }
    }
    return num;
  }

  Future<WhatsAppResult> sendBookingMessage(Appointment appointment) async {
    final phone = formatPhoneForWhatsApp(appointment.barberPhone);
    if (phone == null) {
      final raw = appointment.barberPhone.trim();
      if (raw.isEmpty) {
        return WhatsAppResult.error(
          'El barbero "${appointment.barberName}" no tiene un teléfono registrado.',
        );
      }
      return WhatsAppResult.error(
        'El teléfono del barbero ($raw) no tiene un formato válido para WhatsApp.',
      );
    }

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
    final url = Uri.parse("https://wa.me/$phone?text=$encodedMessage");

    try {
      final canOpen = await canLaunchUrl(url);
      if (!canOpen) {
        return WhatsAppResult.error(
          'No se pudo abrir WhatsApp. El sistema o navegador no reconoce el enlace.',
        );
      }

      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched) {
        return WhatsAppResult.opened();
      }

      final fallbackLaunched = await launchUrl(url);
      if (fallbackLaunched) {
        return WhatsAppResult.opened();
      }

      return WhatsAppResult.error(
        'No se pudo abrir WhatsApp. Verificá si el navegador bloqueó la ventana emergente.',
      );
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
      return WhatsAppResult.error(
        'Ocurrió un error al intentar abrir WhatsApp ($e). Verificá los permisos del navegador.',
      );
    }
  }
}
