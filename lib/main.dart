import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_info.dart';
import 'app/app_identity.dart';
import 'app/cielo_app.dart';
import 'app/font_licenses.dart';
import 'core/concurrency/write_gate.dart';
import 'core/database/app_database.dart';
import 'core/platform/cielo_platform.dart';
import 'features/backup/data/local_backup_service.dart';
import 'features/backup/data/platform_documents.dart';
import 'features/maintenance/data/local_erase_all_service.dart';
import 'features/observations/data/sqlite_observation_store.dart';
import 'features/location/data/geolocator_location_service.dart';
import 'features/map/domain/offline_province_map.dart';
import 'features/media/data/local_audio_player_service.dart';
import 'features/media/data/local_media_service.dart';
import 'features/media/data/local_voice_recorder.dart';
import 'features/media/data/media_maintenance_service.dart';
import 'features/profile/data/sqlite_profile_repository.dart';
import 'features/profile/application/initial_profile_seeder.dart';
import 'features/security/application/app_lock_controller.dart';
import 'features/security/data/device_auth_service.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/data/sqlite_settings_repository.dart';
import 'features/statistics/data/sqlite_stats_service.dart';
import 'app/hito_b_bootstrap.dart';
import 'l10n/cielo_strings.dart';

/// Composición de producción: SQLite privado de la app, sin red.
/// La base se abre de forma perezosa en la primera consulta.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  const platform = CieloPlatform();
  final gate = WriteGate();
  final AppDatabase database = await AppDatabase.android();
  final SqliteObservationStore store = SqliteObservationStore(
    database: database,
    gate: gate,
  );
  final LocalMediaService media = LocalMediaService(
    database: database,
    gate: gate,
  );
  final maintenance = MediaMaintenanceService(database: database, gate: gate);
  final recorder = LocalVoiceRecorder(media: media);
  final player = LocalAudioPlayerService(media: media);
  final eraseAll = LocalEraseAllService(
    database: database,
    gate: gate,
    // Fuera de Android el directorio temporal es compartido: no se toca.
    cacheDirectory: Platform.isAndroid ? getTemporaryDirectory : null,
    clearPreferences: Platform.isAndroid ? platform.clearPreferences : null,
    recorder: recorder,
    player: player,
    resetStaged: media.resetStaged,
  );
  // Un borrado interrumpido se termina antes de recuperar o abrir nada.
  if (await eraseAll.hasPendingErase()) await eraseAll.eraseAll();
  final pendingErase = await eraseAll.hasPendingErase();

  final profile = SqliteProfileRepository(database: database, gate: gate);
  await InitialProfileSeeder(
    repository: profile,
    media: media,
    supportDirectory: getApplicationSupportDirectory,
    profile: AppIdentity.profile,
    photoAsset: AppIdentity.profilePhotoJpegAsset,
    photoThumbnailAsset: AppIdentity.profilePhotoThumbnailAsset,
    loadAsset: (String path) async {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
  ).run();
  const documents = PlatformDocuments();
  final backup = LocalBackupService(
    database: database,
    observations: store,
    profile: profile,
    gate: gate,
    documents: documents,
    appVersion: AppInfo.version,
  );
  await backup.purgeStaging();
  if (!pendingErase) {
    await HitoBBootstrap(
      drafts: store,
      media: media,
      maintenance: maintenance,
    ).run();
  }
  final settings = SettingsController(
    repository: SqliteSettingsRepository(database: database, gate: gate),
  );
  await settings.load();
  final lock = AppLockController(
    settings: settings,
    auth: DeviceAuthService(),
    unlockReason: CieloStrings.lockReasonOpen,
    onPrivacyChanged: (hidden) =>
        unawaited(platform.setRecentsPrivacy(hidden).catchError((Object _) {})),
  );
  final map = OfflineProvinceMap.parse(
    await rootBundle.loadString('assets/maps/dominican_republic_adm1.geojson'),
  );
  runApp(
    CieloApp(
      observations: store,
      observationService: store,
      drafts: store,
      locationService: GeolocatorLocationService(),
      mediaService: media,
      recorder: recorder,
      player: player,
      provinceMap: map,
      maintenance: maintenance,
      settings: settings,
      lock: lock,
      profile: profile,
      stats: SqliteStatsService(database: database, provinceMap: map),
      backup: backup,
      documents: documents,
      eraseAll: eraseAll,
      pendingErase: pendingErase,
    ),
  );
}
