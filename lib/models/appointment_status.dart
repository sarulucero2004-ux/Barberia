enum AppointmentStatus {
  pending('Pendiente'),
  confirmed('Confirmado'),
  cancelled('Cancelado'),
  completed('Finalizado');

  final String displayName;
  const AppointmentStatus(this.displayName);

  static AppointmentStatus fromString(String value) {
    return AppointmentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppointmentStatus.pending,
    );
  }

  String toJson() => name;
}
