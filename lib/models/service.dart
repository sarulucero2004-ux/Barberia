class Service {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'descripcion': description,
      'precio': price,
      'duracion': durationMinutes,
    };
  }

  /// Convierte un valor de Firestore a texto sin lanzar.
  /// `?? ''` solo protege contra `null`: si el documento guardó, por ejemplo,
  /// un número o una lista en vez de texto, la asignación a un `String`
  /// lanzaría un `TypeError` y abortaría la lectura de toda la colección.
  static String _toText(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Convierte un valor numérico de Firestore a [double].
  /// Firestore puede devolver `int`, `double` o texto numérico según cómo se
  /// haya creado el documento, así que no se puede asumir un único tipo.
  static double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Convierte un valor numérico de Firestore a [int] de forma segura.
  /// Evita que un `duracion` guardado como `30.0` o `"30"` rompa la lectura
  /// de toda la colección.
  static int _toInt(dynamic value, [int fallback = 30]) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Nunca debe lanzar: un único documento con un tipo inesperado en cualquier
  /// campo rompería la carga completa de `servicios` en la página principal.
  factory Service.fromMap(Map<String, dynamic> map, String docId) {
    return Service(
      id: docId,
      name: _toText(map['nombre']),
      description: _toText(map['descripcion']),
      price: _toDouble(map['precio']),
      durationMinutes: _toInt(map['duracion']),
    );
  }
}
