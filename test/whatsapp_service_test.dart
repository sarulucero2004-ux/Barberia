import 'package:flutter_test/flutter_test.dart';

import 'package:barberia/services/whatsapp_service.dart';

void main() {
  final service = WhatsAppService();

  group('WhatsAppService customer phone', () {
    test('accepts formatted Argentine and international phone numbers', () {
      expect(service.isValidPhoneForWhatsApp('+54 9 11 1234-5678'), isTrue);
      expect(service.isValidPhoneForWhatsApp('+1 (202) 555-0123'), isTrue);
    });

    test('rejects empty or structurally invalid phone numbers', () {
      expect(service.isValidPhoneForWhatsApp(''), isFalse);
      expect(service.isValidPhoneForWhatsApp('phone 2025550123'), isFalse);
      expect(service.isValidPhoneForWhatsApp('+1 234'), isFalse);
    });

    test('builds a wa.me link with normalized international digits', () {
      expect(
        service.buildCustomerChatUri('+1 (202) 555-0123').toString(),
        'https://wa.me/12025550123',
      );
      expect(
        service.buildCustomerChatUri('+54 9 11 1234-5678').toString(),
        'https://wa.me/5491112345678',
      );
      expect(service.buildCustomerChatUri('invalid'), isNull);
    });
  });
}
