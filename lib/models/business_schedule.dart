/// Configuración global de horarios de atención del negocio (`config/negocio`).
///
/// Reemplaza las listas de horarios que estaban hardcodeadas en el código.
/// Los horarios son GLOBALES: los usa tanto B1 como B2. La diferencia entre
/// barberos sigue viniendo exclusivamente de la ocupación (`turnos` y
/// `disponibilidad`), nunca de esta configuración.
///
/// Importante: en un [ScheduleRange], `fin` es el **inicio del último slot**
/// del tramo, no la hora de cierre del negocio. Un tramo 09:00–13:30 produce
/// los slots 09:00, 09:30, ... 13:30, y el de las 13:30 termina a las 14:00.
library;

/// Un tramo de atención continuo dentro de un día, guardado en minutos desde
/// medianoche para poder generar los slots sin parsear strings.
class ScheduleRange {
  /// Inicio del primer slot del tramo, en minutos desde medianoche.
  final int startMinutes;

  /// Inicio del último slot del tramo, en minutos desde medianoche.
  final int endMinutes;

  const ScheduleRange({required this.startMinutes, required this.endMinutes});

  /// Parsea un tramo desde Firestore. Devuelve `null` si los datos son
  /// inválidos, para descartar el tramo en lugar de romper toda la agenda.
  static ScheduleRange? fromMap(Map<dynamic, dynamic> map) {
    final inicio = _toMinutes(map['inicio']);
    final fin = _toMinutes(map['fin']);
    if (inicio == null || fin == null) return null;
    if (fin < inicio) return null;
    return ScheduleRange(startMinutes: inicio, endMinutes: fin);
  }

  /// Convierte "HH:mm" a minutos desde medianoche. Tolerante a basura.
  static int? _toMinutes(dynamic value) {
    if (value is int) return value;
    if (value is! String) return null;
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 47 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }
}

/// Un día de la semana dentro de la configuración de horarios.
class ScheduleDay {
  final bool abierto;
  final List<ScheduleRange> tramos;

  const ScheduleDay({required this.abierto, required this.tramos});

  static ScheduleDay fromMap(Map<dynamic, dynamic> map) {
    final abierto = map['abierto'] is bool ? map['abierto'] as bool : true;
    final tramos = <ScheduleRange>[];
    final rawTramos = map['tramos'];
    if (rawTramos is List) {
      for (final raw in rawTramos) {
        if (raw is! Map) continue;
        final rango = ScheduleRange.fromMap(raw);
        if (rango != null) tramos.add(rango);
      }
    }
    return ScheduleDay(abierto: abierto, tramos: tramos);
  }
}

/// Documento `config/negocio`: horarios de atención de toda la semana.
class BusinessSchedule {
  /// Longitud de cada slot en minutos. Es el paso de generación de los
  /// horarios de inicio y también la duración que se muestra como horario
  /// final. La app no usa la duración de los servicios para esto.
  final int slotMinutos;

  /// Días indexados por `DateTime.weekday` (1 = lunes ... 7 = domingo).
  final Map<int, ScheduleDay> dias;

  const BusinessSchedule({required this.slotMinutos, required this.dias});

  /// Lee `config/negocio`. Lanza [FormatException] si el documento no contiene
  /// una configuración utilizable, para que el provider la trate como error en
  /// lugar de mostrar una agenda vacía o inventada.
  factory BusinessSchedule.fromMap(Map<String, dynamic> map) {
    final rawSlot = map['slotMinutos'];
    final slotMinutos = rawSlot is int && rawSlot > 0 ? rawSlot : 30;

    final dias = <int, ScheduleDay>{};
    final rawDias = map['dias'];
    if (rawDias is Map) {
      rawDias.forEach((key, value) {
        if (value is! Map) return;
        final indice = int.tryParse('$key');
        if (indice == null) return;
        // Firestore usa "0" = domingo; Dart usa 7 = domingo.
        final weekday = indice == 0 ? DateTime.sunday : indice;
        if (weekday < DateTime.monday || weekday > DateTime.sunday) return;
        dias[weekday] = ScheduleDay.fromMap(value);
      });
    }

    if (dias.isEmpty) {
      throw const FormatException('La configuración de horarios no contiene días.');
    }

    return BusinessSchedule(slotMinutos: slotMinutos, dias: dias);
  }

  /// Genera los horarios de inicio para un día de la semana, en orden.
  ///
  /// Devuelve una lista vacía si el día está cerrado, no configurado o no tiene
  /// tramos válidos. Nunca inventa horarios.
  List<String> getSlotsForWeekday(int weekday) {
    final day = dias[weekday];
    if (day == null || !day.abierto || day.tramos.isEmpty) return const [];

    final resultado = <String>[];
    for (final rango in day.tramos) {
      for (int minuto = rango.startMinutes;
          minuto <= rango.endMinutes;
          minuto += slotMinutos) {
        resultado.add(formatMinutes(minuto));
      }
    }
    return resultado;
  }

  /// `true` si el día tiene atención configurada. Preparado para una segunda
  /// etapa en la que se filtren los días cerrados del selector de fechas.
  bool isOpenOn(int weekday) {
    final day = dias[weekday];
    return day != null && day.abierto && day.tramos.isNotEmpty;
  }

  /// Convierte minutos desde medianoche a "HH:mm".
  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
