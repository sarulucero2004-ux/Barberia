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

  factory Service.fromMap(Map<String, dynamic> map, String docId) {
    return Service(
      id: docId,
      name: map['nombre'] ?? '',
      description: map['descripcion'] ?? '',
      price: (map['precio'] ?? 0.0).toDouble(),
      durationMinutes: map['duracion'] ?? 30,
    );
  }
}
