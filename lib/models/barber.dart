class Barber {
  final String id;
  final String name;
  final String phone;
  final String specialty;

  Barber({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
  });

  String get imageAssetPath {
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
    };
  }

  factory Barber.fromMap(Map<String, dynamic> map, String docId) {
    return Barber(
      id: docId,
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? '',
      specialty: map['especialidad'] ?? '',
    );
  }
}
