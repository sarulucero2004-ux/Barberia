class Barber {
  final String id;
  final String name;
  final String phone;
  final String imageUrl;
  final String specialty;

  Barber({
    required this.id,
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.specialty,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'telefono': phone,
      'imagenUrl': imageUrl,
      'especialidad': specialty,
    };
  }

  factory Barber.fromMap(Map<String, dynamic> map, String docId) {
    return Barber(
      id: docId,
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? '',
      imageUrl: map['imagenUrl'] ?? '',
      specialty: map['especialidad'] ?? '');
  }
}
