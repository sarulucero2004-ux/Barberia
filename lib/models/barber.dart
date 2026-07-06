class Barber {
  final String id;
  final String name;
  final String phone;
  final String imageUrl;
  final String specialty;
  final double rating;

  Barber({
    required this.id,
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.specialty,
    required this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'telefono': phone,
      'imagenUrl': imageUrl,
      'especialidad': specialty,
      'puntuacion': rating,
    };
  }

  factory Barber.fromMap(Map<String, dynamic> map, String docId) {
    return Barber(
      id: docId,
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? '',
      imageUrl: map['imagenUrl'] ?? '',
      specialty: map['especialidad'] ?? '',
      rating: (map['puntuacion'] ?? 0.0).toDouble(),
    );
  }
}
