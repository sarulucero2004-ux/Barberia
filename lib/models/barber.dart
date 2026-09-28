class Barber {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final bool activo;

  Barber({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    this.activo = true,
  });

  String get imageAssetPath {
    // B1 y B2 son IDs fijos: se resuelven primero por ID para que un cambio de
    // `nombre` en Firestore no rompa el asset local.
    switch (id) {
      case 'B1':
        return 'assets/images/barberos/ezequiel.jpg';
      case 'B2':
        return 'assets/images/barberos/isaias.jpg';
    }

    final cleanName = name
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');

    if (cleanName.contains('ezequiel')) {
      return 'assets/images/barberos/ezequiel.jpg';
    } else if (cleanName.contains('isaias')) {
      return 'assets/images/barberos/isaias.jpg';
    } else {
      return 'assets/images/barberos/$cleanName.jpg';
    }
  }

  String get imageUrl => imageAssetPath;

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'telefono': phone,
      'especialidad': specialty,
      'activo': activo,
    };
  }

  factory Barber.fromMap(Map<String, dynamic> map, String docId) {
    return Barber(
      id: docId,
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? '',
      specialty: map['especialidad'] ?? '',
      activo: map['activo'] is bool ? map['activo'] as bool : true,
    );
  }
}
