import 'dart:async';

import 'package:cielo_rd/app/contracts.dart';

final class FakeAuth implements LocalAuthService {
  FakeAuth({this.available = AuthAvailability.available});
  AuthAvailability available;
  AuthOutcome outcome = AuthOutcome.success;
  Completer<AuthOutcome>? pending;
  final reasons = <String>[];

  @override
  Future<AuthAvailability> availability() async => available;

  @override
  Future<AuthOutcome> authenticate(String reason) {
    reasons.add(reason);
    return pending?.future ?? Future.value(outcome);
  }

  @override
  Future<void> cancel() async {}
}

final class MemorySettings implements SettingsRepository {
  MemorySettings([AppSettings? initial]) : value = initial ?? AppSettings();
  AppSettings value;
  AppFailure? getFailure;
  AppFailure? saveFailure;
  int saves = 0;

  @override
  Future<Result<AppSettings>> get() async =>
      getFailure == null ? Success(value) : Failure(getFailure!);

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    if (saveFailure != null) return Failure(saveFailure!);
    saves++;
    value = settings;
    return Success(settings);
  }
}

final class MemoryProfile implements ProfileRepository {
  MemoryProfile([this.value]);
  ObserverProfile? value;
  ObservationMedia? lastPhoto;
  AppFailure? failure;

  @override
  Future<Result<ObserverProfile?>> get() async =>
      failure == null ? Success(value) : Failure(failure!);

  @override
  Future<Result<ObserverProfile>> save(
    ObserverProfile profile, {
    ObservationMedia? newPhoto,
  }) async {
    if (failure != null) return Failure(failure!);
    value = profile;
    lastPhoto = newPhoto;
    return Success(profile);
  }
}

final class FakeMediaService implements MediaService {
  final committed = <String>[];
  final discarded = <String>[];
  int _next = 0;
  Result<ObservationMedia?>? pickResult;

  @override
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source) async =>
      pickResult ??
      Success(
        ObservationMedia(
          id: 'photo-${++_next}',
          kind: MediaKind.photo,
          relativePath: 'media/photos/photo-$_next.jpg',
          mimeType: 'image/jpeg',
          byteSize: 10,
        ),
      );

  @override
  Future<Result<List<ObservationMedia>>> recoverPhotos() async =>
      const Success([]);

  @override
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds) async {
    committed.addAll(mediaIds);
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> discardStaged(String mediaId) async {
    discarded.add(mediaId);
    return const Success(Unit.value);
  }

  @override
  Future<Result<String>> resolveLocalPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));

  @override
  Future<Result<String>> resolveThumbnailPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));
}

final class FakeStats implements StatsService {
  FakeStats(this.result);
  Result<ObservationStats> result;
  ObservationFilter? lastFilter;
  int calls = 0;

  @override
  Future<Result<ObservationStats>> summarize(ObservationFilter filter) async {
    calls++;
    lastFilter = filter;
    return result;
  }
}

final class FakeDocuments implements DocumentGateway {
  Uri? created = Uri.parse('content://docs/copia.zip');
  Uri? opened = Uri.parse('content://docs/copia.zip');
  String? suggestedName;
  Object? error;

  @override
  Future<Uri?> createDocument({
    required String suggestedName,
    required String mimeType,
  }) async {
    if (error != null) throw error!;
    this.suggestedName = suggestedName;
    return created;
  }

  @override
  Future<Uri?> openDocument({required List<String> mimeTypes}) async {
    if (error != null) throw error!;
    return opened;
  }
}

final class FakeBackup implements BackupService {
  Result<BackupReceipt>? exportResult;
  Result<BackupInspection>? inspectResult;
  Result<ImportReport>? importResult;
  Completer<void>? hold;
  BackupFormat? lastFormat;
  bool? lastIncludeProfile;
  ObservationFilter? lastFilter;
  final discarded = <String>[];
  int imports = 0;

  @override
  Stream<BackupProgress> get progress => const Stream.empty();

  @override
  Future<Result<BackupReceipt>> export({
    required ObservationFilter filter,
    required BackupFormat format,
    required Uri destination,
    bool includeProfile = false,
  }) async {
    lastFormat = format;
    lastIncludeProfile = includeProfile;
    lastFilter = filter;
    await hold?.future;
    return exportResult!;
  }

  @override
  Future<Result<BackupInspection>> inspect(Uri source) async => inspectResult!;

  @override
  Future<Result<ImportReport>> importZip(
    String inspectionToken, {
    ImportConflictPolicy policy = ImportConflictPolicy.importAsCopies,
  }) async {
    imports++;
    return importResult!;
  }

  @override
  Future<void> discardInspection(String inspectionToken) async =>
      discarded.add(inspectionToken);
}

final class FakeErase implements EraseAllService {
  Result<EraseAllPreview> previewResult = const Success(
    EraseAllPreview(
      published: 12,
      drafts: 1,
      photos: 30,
      audios: 4,
      hasProfile: true,
      hasProfilePhoto: true,
      hasSettings: true,
      temporaryFiles: 3,
    ),
  );
  final results = <Result<EraseAllReport>>[];
  int calls = 0;

  @override
  Future<Result<EraseAllPreview>> preview() async => previewResult;

  @override
  Future<Result<EraseAllReport>> eraseAll() async {
    calls++;
    return results.isEmpty
        ? const Success(EraseAllReport(pendingFiles: 0))
        : results.removeAt(0);
  }

  @override
  Future<bool> hasPendingErase() async => false;
}

ObservationStats sampleStats() => ObservationStats(
  total: 24,
  knownDurationSeconds: 5400,
  withKnownDuration: 9,
  byCategory: const {
    ObservationCategory.astronomy: 14,
    ObservationCategory.atmospheric: 6,
    ObservationCategory.birds: 4,
  },
  byLocalDate: const {
    '2026-03-02': 3,
    '2026-09-10': 8,
    '2026-11-02': 5,
    '2026-11-21': 8,
  },
  byLocalHour: const {5: 2, 19: 4, 20: 8, 22: 10},
  byProvince: const {'La Vega': 9, 'Samaná': 5},
  byPlace: const [
    PlaceCount(place: 'Parque Nacional Valle Nuevo, Constanza', count: 9),
    PlaceCount(place: 'Samaná', count: 5),
  ],
);
