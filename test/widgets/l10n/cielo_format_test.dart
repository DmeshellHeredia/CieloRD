import 'package:cielo_rd/l10n/cielo_format.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter_test/flutter_test.dart';

const String nbsp = ' ';

void main() {
  final DateTime now = DateTime(2026, 11, 22, 21, 30);

  group('Fechas', () {
    test('fecha corta sin año si es el año actual', () {
      expect(CieloFormat.dateShort(DateTime(2026, 11, 22), now: now), 'dom 22 nov');
      expect(CieloFormat.dateShort(DateTime(2026, 11, 21), now: now), 'sáb 21 nov');
    });

    test('fecha corta con año si es de otro año', () {
      expect(CieloFormat.dateShort(DateTime(2025, 12, 3), now: now), 'mié 3 dic 2025');
    });

    test('fecha larga para lectores de pantalla', () {
      expect(CieloFormat.dateLong(DateTime(2026, 12, 2)), 'miércoles, 2 de diciembre de 2026');
    });
  });

  group('Hora en 12 h', () {
    test('noche, mediodía, medianoche y mañana', () {
      expect(CieloFormat.time(DateTime(2026, 1, 1, 21, 14)), '9:14${nbsp}p.${nbsp}m.');
      expect(CieloFormat.time(DateTime(2026, 1, 1, 12, 0)), '12:00${nbsp}p.${nbsp}m.');
      expect(CieloFormat.time(DateTime(2026, 1, 1, 0, 5)), '12:05${nbsp}a.${nbsp}m.');
      expect(CieloFormat.time(DateTime(2026, 1, 1, 5, 40)), '5:40${nbsp}a.${nbsp}m.');
    });

    test('fecha y hora combinadas', () {
      expect(
        CieloFormat.dateTime(DateTime(2026, 11, 17, 2, 40), now: now),
        'mar 17 nov, 2:40${nbsp}a.${nbsp}m.',
      );
    });
  });

  group('Duración', () {
    test('formato visible', () {
      expect(CieloFormat.duration(const Duration(seconds: 45)), '45${nbsp}s');
      expect(CieloFormat.duration(const Duration(minutes: 3)), '3${nbsp}min');
      expect(CieloFormat.duration(const Duration(minutes: 1, seconds: 30)), '1${nbsp}min 30${nbsp}s');
      expect(CieloFormat.duration(const Duration(hours: 1, minutes: 5)), '1${nbsp}h 5${nbsp}min');
      expect(CieloFormat.duration(Duration.zero), '0${nbsp}s');
    });

    test('formato hablado', () {
      expect(CieloFormat.durationSpoken(const Duration(minutes: 1, seconds: 30)), '1 minuto y 30 segundos');
      expect(CieloFormat.durationSpoken(const Duration(hours: 2)), '2 horas');
      expect(
        CieloFormat.durationSpoken(const Duration(hours: 1, minutes: 1, seconds: 1)),
        '1 hora, 1 minuto y 1 segundo',
      );
    });
  });

  test('coordenadas con hemisferio y Oeste como "O"', () {
    expect(CieloFormat.coordinates(18.48612, -69.93121), '18.4861°${nbsp}N, 69.9312°${nbsp}O');
    expect(CieloFormat.coordinates(-1, 2), '1.0000°${nbsp}S, 2.0000°${nbsp}E');
    expect(CieloFormat.accuracy(12.4), '±12${nbsp}m');
  });

  test('plurales de medios', () {
    expect(CieloStrings.photos(1), '1 foto');
    expect(CieloStrings.photos(3), '3 fotos');
    expect(CieloStrings.voiceNotes(1), '1 nota de voz');
    expect(CieloStrings.voiceNotes(2), '2 notas de voz');
    expect(CieloStrings.draftsPending(2), '2 borradores por completar');
  });
}
