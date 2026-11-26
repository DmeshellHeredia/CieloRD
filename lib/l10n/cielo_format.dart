/// Formatos de fecha, hora, duración y coordenadas en español dominicano,
/// sin dependencias externas.
///
/// Las fechas se reciben ya en hora local: convertir desde UTC más el
/// desplazamiento original es responsabilidad de la capa de datos.
abstract final class CieloFormat {
  static const List<String> _weekdays = <String>['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const List<String> _weekdaysLong = <String>[
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo', //
  ];
  static const List<String> _months = <String>[
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic', //
  ];
  static const List<String> _monthsLong = <String>[
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Espacio de no separación: evita que "p. m." quede sola en otra línea.
  static const String _nbsp = ' ';

  /// "sáb 22 nov" o "sáb 22 nov 2025" si el año no es el actual.
  static String dateShort(DateTime date, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    final String base = '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
    return date.year == ref.year ? base : '$base ${date.year}';
  }

  /// "sábado, 22 de noviembre de 2026" — para lectores de pantalla y detalle.
  static String dateLong(DateTime date) =>
      '${_weekdaysLong[date.weekday - 1]}, ${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';

  /// "Noviembre de 2026" — encabezado de grupo mensual.
  static String monthYear(DateTime date) {
    final String month = _monthsLong[date.month - 1];
    return '${month[0].toUpperCase()}${month.substring(1)} de ${date.year}';
  }

  /// "9:14 p. m." en formato de 12 horas, habitual en República Dominicana.
  static String time(DateTime date) {
    final int h12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minutes = date.minute.toString().padLeft(2, '0');
    final String period = date.hour < 12 ? 'a.${_nbsp}m.' : 'p.${_nbsp}m.';
    return '$h12:$minutes$_nbsp$period';
  }

  /// "sáb 22 nov, 9:14 p. m."
  static String dateTime(DateTime date, {DateTime? now}) => '${dateShort(date, now: now)}, ${time(date)}';

  /// "45 s", "3 min", "1 min 30 s", "1 h 5 min".
  static String duration(Duration d) {
    final int total = d.inSeconds.abs();
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    final List<String> parts = <String>[
      if (h > 0) '$h${_nbsp}h',
      if (m > 0) '$m${_nbsp}min',
      if (s > 0 && h == 0) '$s${_nbsp}s',
    ];
    return parts.isEmpty ? '0${_nbsp}s' : parts.join(' ');
  }

  /// Duración leída por TalkBack: "1 minuto y 30 segundos".
  static String durationSpoken(Duration d) {
    final int total = d.inSeconds.abs();
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    String unit(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final List<String> parts = <String>[
      if (h > 0) unit(h, 'hora', 'horas'),
      if (m > 0) unit(m, 'minuto', 'minutos'),
      if (s > 0) unit(s, 'segundo', 'segundos'),
    ];
    if (parts.isEmpty) return '0 segundos';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
  }

  /// "18.4861° N, 69.9312° O" — 4 decimales (≈ 11 m). Oeste se abrevia "O".
  static String coordinates(double latitude, double longitude) {
    final String lat = '${latitude.abs().toStringAsFixed(4)}°$_nbsp${latitude >= 0 ? 'N' : 'S'}';
    final String lon = '${longitude.abs().toStringAsFixed(4)}°$_nbsp${longitude >= 0 ? 'E' : 'O'}';
    return '$lat, $lon';
  }

  /// "±12 m"
  static String accuracy(double meters) => '±${meters.round()}${_nbsp}m';
}
