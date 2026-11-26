# CieloRD — Contratos públicos del Hito B

Fecha: 23-11-2026. Estas son las firmas que la UI y las pruebas deben consumir;
la implementación concreta se inyecta por constructor.

## Ubicación

```dart
enum LocationPermission {
  notDetermined,
  denied,
  deniedPermanently,
  approximate,
  precise,
}

final class LocationFix {
  LocationFix({required ObservationLocation location, required DateTime capturedAt});
  final ObservationLocation location;
  final DateTime capturedAt;
}

abstract interface class LocationService {
  Future<Result<LocationPermission>> permission();
  Future<Result<LocationFix>> current({
    Duration timeout = const Duration(seconds: 20),
  });
}
```

`permission()` nunca abre un diálogo. `current()` puede solicitar únicamente
permiso foreground tras una acción explícita. `capturedAt` se normaliza a UTC.

## Multimedia

```dart
enum PhotoSource { camera, gallery }
enum RecorderPhase { idle, recording, stopping, completed, failed }
enum PlayerPhase { idle, loading, paused, playing, completed, failed }

final class RecordingState {
  const RecordingState({
    required RecorderPhase phase,
    Duration elapsed = Duration.zero,
    AppFailure? failure,
    ObservationMedia? media,
  });
}

final class PlaybackState {
  const PlaybackState({
    required PlayerPhase phase,
    Duration position = Duration.zero,
    Duration? duration,
    AppFailure? failure,
    String? mediaId,
  });
}

abstract interface class MediaService {
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source);
  Future<Result<List<ObservationMedia>>> recoverPhotos();
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds);
  Future<Result<Unit>> discardStaged(String mediaId);
  Future<Result<String>> resolveLocalPath(String mediaId);
  Future<Result<String>> resolveThumbnailPath(String mediaId);
}

abstract interface class VoiceRecorder {
  Stream<RecordingState> get states;
  Future<Result<Unit>> start();
  Future<Result<ObservationMedia>> stop();
  Future<Result<Unit>> cancel();
  Future<void> dispose();
}

abstract interface class AudioPlayerService {
  Stream<PlaybackState> get states;
  Future<Result<Unit>> load(String mediaId);
  Future<Result<Unit>> play();
  Future<Result<Unit>> pause();
  Future<Result<Unit>> seek(Duration position);
  Future<Result<Unit>> stop();
  Future<void> dispose();
}

final class MediaMaintenanceReport {
  const MediaMaintenanceReport({
    required int deletedPending,
    required int failedPending,
    required int deletedOrphans,
  });
}

abstract interface class MediaMaintenance {
  Future<Result<MediaMaintenanceReport>> run();
}
```

`pickPhoto()` devuelve `Success(null)` al cancelar. Los adjuntos nuevos son
staged; la UI confirma con `commitStaged()` solo después de guardar SQLite y
descarta con `discardStaged()` al cancelar. La UI nunca abre `relativePath`
directamente.

## Modelos extendidos

```dart
enum LocationSource { text, manual, gps }
enum MediaKind { photo, audio }

final class ObservationLocation {
  const ObservationLocation({
    String? placeName,
    double? latitude,
    double? longitude,
    LocationSource? source,
    double? accuracyM,
    DateTime? capturedAt,
  });
  bool get hasCoordinates;
}

final class ObservationMedia {
  const ObservationMedia({
    required String id,
    required MediaKind kind,
    required String relativePath,
    required String mimeType,
    required int byteSize,
    String? sha256,
    int? durationMs,
  });
}
```

Para datos manuales/texto, `accuracyM` y `capturedAt` son nulos. Observaciones
anteriores a SQLite v3 conservan ubicación y reciben `capturedAt == null`.

## Mapa offline

```dart
final class GeoCoordinate {
  const GeoCoordinate(double latitude, double longitude);
}

abstract final class WebMercator {
  static ProjectedCoordinate project(GeoCoordinate value);
  static GeoCoordinate unproject(ProjectedCoordinate value);
}

final class OfflineProvinceMap {
  factory OfflineProvinceMap.parse(String source);
  ProvinceBoundary? provinceAt(GeoCoordinate point);
}
```

`OfflineProvinceMap` acepta GeoJSON `Polygon`/`MultiPolygon`; no realiza I/O de
red. La UI compartida es `ProvinceMapView` sobre `CustomPainter` e
`InteractiveViewer`.

## Composición

`CieloApp` acepta opcionalmente por constructor `LocationService`,
`MediaService`, `VoiceRecorder`, `AudioPlayerService`, `OfflineProvinceMap` y
`MediaMaintenance`. `HitoBBootstrap.run()` recupera fotos perdidas, crea el
borrador, confirma sus archivos y ejecuta mantenimiento en ese orden.

Rutas públicas añadidas:

```dart
static const String CieloRoutes.map = '/mapa';
```
