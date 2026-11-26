import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/backup/data/backup_codec.dart';
import 'package:cielo_rd/features/backup/data/platform_documents.dart';
import 'package:cielo_rd/features/backup/data/strict_zip.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/hito_c_env.dart';

final class _BrokenDocuments implements DocumentStore {
  const _BrokenDocuments();

  @override
  Future<void> write(File source, Uri destination) async {
    await File(destination.toFilePath()).writeAsString('a medias');
    throw const FileSystemException('No space left on device');
  }

  @override
  Future<void> read(Uri source, File destination, {required int maxBytes}) =>
      throw const FileSystemException('proveedor caído');

  @override
  Future<void> discard(Uri destination, {required bool onlyIfEmpty}) =>
      const PlatformDocuments().discard(destination, onlyIfEmpty: onlyIfEmpty);
}

Future<BackupReceipt> _export(
  HitoCEnv env, {
  String name = 'copia.zip',
  BackupFormat format = BackupFormat.zipComplete,
  bool includeProfile = true,
}) async => ok<BackupReceipt>(
  await env.backup.export(
    filter: ObservationFilter(status: null),
    format: format,
    destination: env.outsideUri(name),
    includeProfile: includeProfile,
  ),
);

/// Entradas de un ZIP leídas con una implementación independiente.
Map<String, Uint8List> _unzip(File file) {
  final archive = ZipDecoder().decodeBytes(
    file.readAsBytesSync(),
    verify: true,
  );
  return {for (final f in archive.files) f.name: f.readBytes()!};
}

Future<File> _zip(HitoCEnv env, Map<String, List<int>> entries) async {
  final file = File(
    '${env.outside.path}/armado_${DateTime.now().microsecondsSinceEpoch}.zip',
  );
  final writer = await StreamingZipWriter.create(file, DateTime.utc(2026));
  for (final entry in entries.entries) {
    await writer.addBytes(entry.key, entry.value);
  }
  await writer.finish();
  return file;
}

Map<String, Object?> _json(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

/// Sustituye `data.json` y actualiza su tamaño y hash en el manifiesto.
Map<String, List<int>> _withData(
  Map<String, Uint8List> entries,
  void Function(Map<String, Object?> data) edit,
) {
  final data = _json(entries['data.json']!);
  edit(data);
  final bytes = utf8.encode(jsonEncode(data));
  final manifest = _json(entries['manifest.json']!);
  manifest['data'] = {
    'path': 'data.json',
    'byteSize': bytes.length,
    'sha256': crypto.sha256.convert(bytes).toString(),
  };
  return {
    ...entries,
    'data.json': bytes,
    'manifest.json': utf8.encode(jsonEncode(manifest)),
  };
}

void main() {
  group('Exportación', () {
    test('JSON válido, completo y sin archivos ni preferencias', () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      ok(
        await env.settings.save(
          AppSettings(theme: AppTheme.day, authenticationEnabled: true),
        ),
      );
      final receipt = await _export(
        env,
        name: 'datos.json',
        format: BackupFormat.jsonMetadata,
      );
      expect(receipt.includesMedia, isFalse);
      expect(receipt.observationCount, 2);
      final text = File('${env.outside.path}/datos.json').readAsStringSync();
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['format'], 'cielord-export');
      expect(json['includesMediaFiles'], isFalse);
      expect(json['appVersion'], '1.0.0');
      final observations = (json['observations']! as List)
          .cast<Map<String, Object?>>();
      final full = observations.singleWhere((o) => o['id'] == seeded.full.id);
      expect(full['title'], 'Leónidas sobre Constanza');
      expect(full['description'], contains('🌠'));
      expect(full['observedAt'], '2026-11-22T02:00:00.000Z');
      expect((full['location']! as Map)['latitude'], 18.8012345);
      expect(
        (full['location']! as Map)['capturedAt'],
        contains('01:59:30.250Z'),
      );
      expect((json['profile']! as Map)['studentId'], '00-PRUEBA');
      for (final secret in ['authentication', 'theme', env.root.path, 'C:\\']) {
        expect(text, isNot(contains(secret)));
      }
      expect(env.privateFiles().where((f) => f.contains('staging')), isEmpty);
    });

    test('ZIP válido para otra implementación; manifiesto exacto', () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      final receipt = await _export(env);
      expect(receipt.mediaCount, 4);
      expect(receipt.missingMedia, 0);
      final file = File('${env.outside.path}/copia.zip');
      expect(receipt.byteSize, file.lengthSync());
      final entries = _unzip(file);
      final manifest = _json(entries['manifest.json']!);
      expect(manifest['schemaVersion'], 1);
      expect(manifest['createdAt'], '2026-11-23T22:00:00.000Z');
      expect(manifest['appVersion'], '1.0.0');
      expect(manifest['databaseVersion'], 4);
      expect(manifest['counts'], {
        'observations': 2,
        'drafts': 1,
        'photos': 3,
        'audios': 1,
        'profile': true,
      });
      final files = (manifest['files']! as List).cast<Map<String, Object?>>();
      expect(entries.keys.toSet(), {
        'manifest.json',
        'data.json',
        for (final f in files) f['path'],
      });
      for (final f in files) {
        final bytes = entries[f['path']]!;
        expect(bytes.length, f['byteSize']);
        expect(crypto.sha256.convert(bytes).toString(), f['sha256']);
      }
      final data = manifest['data']! as Map<String, Object?>;
      expect(
        crypto.sha256.convert(entries['data.json']!).toString(),
        data['sha256'],
      );
      for (final m in seeded.full.input.media) {
        expect(
          entries[m.relativePath],
          env.file(m.relativePath).readAsBytesSync(),
        );
      }
    });

    test('sin perfil cuando no se pide', () async {
      final env = await HitoCEnv.create();
      await env.seed();
      await _export(env, includeProfile: false);
      final entries = _unzip(File('${env.outside.path}/copia.zip'));
      expect(_json(entries['data.json']!)['profile'], isNull);
      expect(entries.keys.where((k) => k.startsWith('media/')), hasLength(3));
    });

    test(
      'un adjunto perdido o dañado se informa y no rompe la copia',
      () async {
        final env = await HitoCEnv.create();
        final seeded = await env.seed();
        env.file(seeded.full.input.media[0].relativePath).deleteSync();
        env
            .file(seeded.full.input.media[2].relativePath)
            .writeAsStringSync('esto no es audio');
        final receipt = await _export(env);
        expect(receipt.missingMedia, 2);
        expect(receipt.mediaCount, 2);
        final other = await HitoCEnv.create();
        final inspection = ok<BackupInspection>(
          await other.backup.inspect(env.outsideUri('copia.zip')),
        );
        expect(inspection.warnings, ['missing_media:2']);
      },
    );

    test('base vacía: copia válida e importable', () async {
      final env = await HitoCEnv.create();
      await _export(env);
      final inspection = ok<BackupInspection>(
        await env.backup.inspect(env.outsideUri('copia.zip')),
      );
      expect(inspection.observationCount, 0);
      expect(inspection.hasProfile, isFalse);
    });

    test('si falla al escribir no deja un archivo a medias', () async {
      final env = await HitoCEnv.create();
      await env.seed();
      env
        ..documents = const _BrokenDocuments()
        ..rebuildBackup();
      final before = await env.dump();
      final failure = failed(
        await env.backup.export(
          filter: ObservationFilter(status: null),
          format: BackupFormat.zipComplete,
          destination: env.outsideUri('rota.zip'),
        ),
      );
      expect(failure.code, FailureCode.storageFull);
      expect(File('${env.outside.path}/rota.zip').existsSync(), isFalse);
      expect(env.privateFiles().where((f) => f.contains('staging')), isEmpty);
      expect(await env.dump(), before);
    });

    test('si falla antes de escribir respeta un archivo existente', () async {
      final env = await HitoCEnv.create();
      await env.seed();
      env
        ..limits = const BackupLimits(totalBytes: 10)
        ..rebuildBackup();
      final existing = File('${env.outside.path}/mio.zip')
        ..writeAsStringSync('contenido previo');
      final failure = failed(
        await env.backup.export(
          filter: ObservationFilter(status: null),
          format: BackupFormat.zipComplete,
          destination: existing.absolute.uri,
        ),
      );
      expect(failure.fieldErrors['backup'], BackupErrors.tooLarge);
      expect(existing.readAsStringSync(), 'contenido previo');
    });
  });

  group('Round-trip', () {
    test('exportar → teléfono vacío → importar conserva todo', () async {
      final source = await HitoCEnv.create();
      final seeded = await source.seed();
      await _export(source);

      final target = await HitoCEnv.create();
      target.prefix = 'b';
      final inspection = ok<BackupInspection>(
        await target.backup.inspect(source.outsideUri('copia.zip')),
      );
      expect(inspection.observationCount, 2);
      expect(inspection.draftCount, 1);
      expect(inspection.photoCount, 3);
      expect(inspection.audioCount, 1);
      expect(inspection.appVersion, '1.0.0');
      expect(inspection.formatVersion, 1);
      expect(inspection.newCount, 2);
      expect(inspection.copyCount, 0);
      expect(inspection.willImportProfile, isTrue);
      expect(
        (await target.rowCounts())['observations'],
        0,
        reason: 'inspeccionar no cambia datos',
      );

      final report = ok<ImportReport>(
        await target.backup.importZip(inspection.token),
      );
      expect(report.importedObservations, 2);
      expect(report.importedMedia, 4);
      expect(report.profileImported, isTrue);
      await target.restart();

      for (final original in [seeded.full, seeded.draft]) {
        final copy = ok<Observation>(await target.store.getById(original.id));
        expect(copy.status, original.status);
        expect(copy.createdAt, original.createdAt);
        expect(copy.updatedAt, original.updatedAt);
        expect(copy.revision, original.revision);
        expect(
          BackupCodec.fingerprint(copy, (m) => m.sha256!),
          BackupCodec.fingerprint(original, (m) => m.sha256!),
        );
        for (final m in original.input.media) {
          expect(
            target.file(m.relativePath).readAsBytesSync(),
            source.file(m.relativePath).readAsBytesSync(),
          );
        }
      }
      final loc = ok<Observation>(await target.store.getById(seeded.full.id))
          .input
          .location!;
      expect(loc.latitude, 18.8012345);
      expect(loc.accuracyM, 6.5);
      expect(loc.capturedAt, DateTime.utc(2026, 11, 22, 1, 59, 30, 250));
      final profile = ok<ObserverProfile?>(await target.profile.get())!;
      expect(profile.motto, 'Mirar arriba');
      ok(await target.media.resolveLocalPath(profile.photoMediaId!));
      ok(await target.media.resolveThumbnailPath(profile.photoMediaId!));
      // La búsqueda normalizada funciona en los importados.
      expect(
        ok<int>(
          await target.store.count(
            filter: ObservationFilter(query: 'leonidas'),
          ),
        ),
        1,
      );
      // La reconciliación no considera huérfano nada de lo importado.
      final maintenance = ok<MediaMaintenanceReport>(
        await target.maintenance.run(),
      );
      expect(maintenance.deletedOrphans, 0);
      expect(
        target.privateFiles().where((f) => f.contains('staging')),
        isEmpty,
      );
    });

    test('exportar → Borrar Todo → importar recupera el teléfono', () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      await _export(env);
      ok(await env.eraser().eraseAll());
      final inspection = ok<BackupInspection>(
        await env.backup.inspect(env.outsideUri('copia.zip')),
      );
      ok(await env.backup.importZip(inspection.token));
      await env.restart();
      final restored = ok<Observation>(await env.store.getById(seeded.full.id));
      expect(restored.input.media, hasLength(3));
      await _export(env, name: 'segunda.zip');
      expect(
        _unzip(File('${env.outside.path}/segunda.zip'))['data.json'],
        _unzip(File('${env.outside.path}/copia.zip'))['data.json'],
        reason: 'la segunda copia es idéntica a la primera',
      );
    });

    test('acepta un ZIP equivalente rehecho por otra herramienta', () async {
      final env = await HitoCEnv.create();
      await env.seed();
      await _export(env);
      final archive = Archive();
      _unzip(File('${env.outside.path}/copia.zip')).forEach((name, bytes) {
        archive.addFile(ArchiveFile.bytes(name, bytes));
      });
      final rezipped = File('${env.outside.path}/rehecha.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final target = await HitoCEnv.create();
      final inspection = ok<BackupInspection>(
        await target.backup.inspect(rezipped.absolute.uri),
      );
      expect(
        ok<ImportReport>(await target.backup.importZip(inspection.token))
            .importedMedia,
        4,
      );
    });
  });

  group('IDs duplicados', () {
    test('contenido idéntico se omite; reimportar es idempotente', () async {
      final env = await HitoCEnv.create();
      await env.seed();
      await _export(env);
      final before = await env.dump();
      for (var i = 0; i < 2; i++) {
        final inspection = ok<BackupInspection>(
          await env.backup.inspect(env.outsideUri('copia.zip')),
        );
        expect(inspection.identicalCount, 2);
        expect(inspection.newCount + inspection.copyCount, 0);
        expect(inspection.willImportProfile, isFalse);
        final report = ok<ImportReport>(
          await env.backup.importZip(inspection.token),
        );
        expect(report.importedObservations, 0);
        expect(report.skippedIdentical, 2);
      }
      expect(await env.dump(), before);
    });

    test('contenido distinto entra como copia determinista', () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      await _export(env);
      final edited = ok<Observation>(
        await env.store.update(
          seeded.full.id,
          seeded.full.input.copyWith(title: 'Editada en el teléfono'),
          status: ObservationStatus.published,
          expectedRevision: 1,
        ),
      );

      Future<ImportReport> import() async {
        final inspection = ok<BackupInspection>(
          await env.backup.inspect(env.outsideUri('copia.zip')),
        );
        return ok<ImportReport>(await env.backup.importZip(inspection.token));
      }

      final first = await import();
      expect(first.importedAsCopies, 1);
      expect(first.importedMedia, 3);
      final local = ok<Observation>(await env.store.getById(seeded.full.id));
      expect(local.input.title, 'Editada en el teléfono');
      expect(local.revision, edited.revision);
      final print = BackupCodec.fingerprint(seeded.full, (m) => m.sha256!);
      final copy = ok<Observation>(
        await env.store.getById(BackupCodec.copyId(seeded.full.id, print)),
      );
      expect(copy.input.title, seeded.full.input.title);
      expect(
        copy.input.media.map((m) => m.sha256),
        seeded.full.input.media.map((m) => m.sha256),
      );
      expect(
        copy.input.media
            .map((m) => m.id)
            .toSet()
            .intersection(seeded.full.input.media.map((m) => m.id).toSet()),
        isEmpty,
      );
      for (final m in copy.input.media) {
        expect(env.file(m.relativePath).existsSync(), isTrue);
      }

      final second = await import();
      expect(second.importedObservations, 0);
      expect(second.skippedIdentical, 2);
      expect((await env.rowCounts())['observations'], 3);

      // Borrar la copia no afecta a los archivos del original.
      ok(await env.store.delete(copy.id, expectedRevision: copy.revision));
      ok(await env.maintenance.run());
      for (final m in seeded.full.input.media) {
        expect(env.file(m.relativePath).existsSync(), isTrue);
      }
    });

    test('el perfil del teléfono nunca se sobrescribe', () async {
      final source = await HitoCEnv.create();
      await source.seed();
      await _export(source);
      final target = await HitoCEnv.create();
      ok(
        await target.profile.save(const ObserverProfile(firstName: 'Titular')),
      );
      final inspection = ok<BackupInspection>(
        await target.backup.inspect(source.outsideUri('copia.zip')),
      );
      expect(inspection.hasProfile, isTrue);
      expect(inspection.willImportProfile, isFalse);
      final report = ok<ImportReport>(
        await target.backup.importZip(inspection.token),
      );
      expect(report.profileImported, isFalse);
      expect(report.importedMedia, 3, reason: 'sin la foto del perfil');
      expect(
        ok<ObserverProfile?>(await target.profile.get())!.firstName,
        'Titular',
      );
    });

    test('la cola de borrado no elimina lo recién recuperado', () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      await _export(env);
      ok(await env.store.delete(seeded.full.id, expectedRevision: 1));
      expect((await env.rowCounts())['pending_file_deletions'], 3);
      final inspection = ok<BackupInspection>(
        await env.backup.inspect(env.outsideUri('copia.zip')),
      );
      ok(await env.backup.importZip(inspection.token));
      ok(await env.maintenance.run());
      for (final m in seeded.full.input.media) {
        expect(env.file(m.relativePath).existsSync(), isTrue);
      }
    });
  });

  group('Copias rechazadas sin tocar datos', () {
    late HitoCEnv env;
    late Map<String, Uint8List> valid;
    late String before;
    late List<String> filesBefore;

    setUp(() async {
      env = await HitoCEnv.create();
      await env.seed();
      await _export(env);
      valid = _unzip(File('${env.outside.path}/copia.zip'));
      before = await env.dump();
      filesBefore = env.privateFiles();
    });

    Future<void> rejects(File file, String reason, {FailureCode? code}) async {
      final failure = failed(await env.backup.inspect(file.absolute.uri));
      expect(failure.fieldErrors['backup'], reason, reason: failure.message);
      expect(failure.code, code ?? FailureCode.corruptData);
      expect(await env.dump(), before);
      expect(env.privateFiles(), filesBefore);
    }

    File raw(List<int> bytes) =>
        File('${env.outside.path}/cruda.zip')..writeAsBytesSync(bytes);

    test('vacío, texto o truncado', () async {
      await rejects(raw([]), BackupErrors.notAZip);
      await rejects(raw(utf8.encode('hola ' * 50)), BackupErrors.notAZip);
      final bytes = File('${env.outside.path}/copia.zip').readAsBytesSync();
      await rejects(
        raw(bytes.sublist(0, bytes.length ~/ 2)),
        BackupErrors.notAZip,
      );
      await rejects(
        raw(bytes.sublist(0, bytes.length - 1)),
        BackupErrors.notAZip,
      );
      await rejects(raw([0x50, ...bytes]), BackupErrors.structure);
    });

    test('un byte alterado en cada archivo del ZIP', () async {
      final reader = await StrictZipReader.open(
        File('${env.outside.path}/copia.zip'),
        maxEntries: 100,
        maxTotalBytes: 1 << 30,
      );
      final bytes = File('${env.outside.path}/copia.zip').readAsBytesSync();
      for (final entry in reader.entries.values) {
        final mutated = Uint8List.fromList(bytes);
        final at =
            entry.headerOffset +
            30 +
            entry.name.length +
            entry.compressedSize ~/ 2;
        mutated[at] ^= 0x01;
        final failure = failed(
          await env.backup.inspect(raw(mutated).absolute.uri),
        );
        expect(failure.code, FailureCode.corruptData, reason: entry.name);
      }
      expect(await env.dump(), before);
      expect(env.privateFiles(), filesBefore);
    });

    test('hash o tamaño del manifiesto que no coincide', () async {
      final photo = valid.keys.firstWhere((k) => k.startsWith('media/photos'));
      final swapped = Uint8List.fromList(valid[photo]!);
      swapped[swapped.length ~/ 2] ^= 1;
      await rejects(
        await _zip(env, {...valid, photo: swapped}),
        BackupErrors.hash,
      );
      await rejects(
        await _zip(env, {
          ...valid,
          photo: [...valid[photo]!, 0],
        }),
        BackupErrors.size,
      );
      final edited = utf8.encode(
        utf8.decode(valid['data.json']!).replaceFirst('Leónidas', 'Leonidaz'),
      );
      await rejects(
        await _zip(env, {...valid, 'data.json': edited}),
        BackupErrors.size,
      );
    });

    test('versión futura o desconocida', () async {
      for (final version in [2, 0, '1', null]) {
        final manifest = _json(valid['manifest.json']!)
          ..['schemaVersion'] = version;
        await rejects(
          await _zip(env, {
            ...valid,
            'manifest.json': utf8.encode(jsonEncode(manifest)),
          }),
          BackupErrors.version,
          code: FailureCode.unsupportedVersion,
        );
      }
    });

    test('path traversal, rutas absolutas y nombres peligrosos', () async {
      for (final name in [
        '../fuera.txt',
        'media/../../fuera.txt',
        'media/photos/../../../cielo_rd.db',
        '/etc/passwd',
        r'..\fuera.txt',
        r'media\photos\x.jpg',
        'C:/Windows/x',
        'media//photos/x.jpg',
        './manifest.json',
        'media/photos/.',
        'media/photos/',
      ]) {
        await rejects(
          await _zip(env, {
            ...valid,
            name: [1, 2, 3],
          }),
          BackupErrors.unsafePath,
        );
      }
      expect(File('${env.root.path}/fuera.txt').existsSync(), isFalse);
    });

    test('archivos inesperados', () async {
      for (final name in [
        'script.sh',
        'media/photos/x.png',
        'media/photos/x.jpg.exe',
        'media/video/x.mp4',
        'media/photos/sub/x.jpg',
        'media/photos/noregistrada.jpg',
        'media/thumbnails/x.jpg',
        'cielo_rd.db',
      ]) {
        await rejects(
          await _zip(env, {
            ...valid,
            name: [0xff, 0xd8, 0xff],
          }),
          BackupErrors.unexpectedEntry,
        );
      }
    });

    test('falta el manifiesto, los datos o un adjunto', () async {
      for (final name in valid.keys) {
        await rejects(
          await _zip(env, {...valid}..remove(name)),
          BackupErrors.structure,
        );
      }
    });

    test('tipo falso: extensión correcta, contenido no', () async {
      for (final prefix in ['media/photos', 'media/audio']) {
        final path = valid.keys.firstWhere((k) => k.startsWith(prefix));
        final fake = utf8.encode('<html>no es un medio</html>');
        final hash = crypto.sha256.convert(fake).toString();
        final manifest = _json(valid['manifest.json']!);
        final data = _json(valid['data.json']!);
        for (final list in [manifest['files']!, data['media']!]) {
          for (final m in (list as List).cast<Map<String, Object?>>()) {
            if (m['path'] == path) {
              m['byteSize'] = fake.length;
              m['sha256'] = hash;
            }
          }
        }
        final bytes = utf8.encode(jsonEncode(data));
        manifest['data'] = {
          'path': 'data.json',
          'byteSize': bytes.length,
          'sha256': crypto.sha256.convert(bytes).toString(),
        };
        await rejects(
          await _zip(env, {
            ...valid,
            path: fake,
            'data.json': bytes,
            'manifest.json': utf8.encode(jsonEncode(manifest)),
          }),
          BackupErrors.type,
        );
      }
    });

    test('JPEG con firma válida pero ilegible: no se importa nada', () async {
      final path = valid.keys.firstWhere((k) => k.startsWith('media/photos'));
      final fake = [0xff, 0xd8, 0xff, 0xe0, ...List.filled(64, 7)];
      final hash = crypto.sha256.convert(fake).toString();
      final manifest = _json(valid['manifest.json']!);
      final data = _json(valid['data.json']!);
      for (final list in [manifest['files']!, data['media']!]) {
        for (final m in (list as List).cast<Map<String, Object?>>()) {
          if (m['path'] == path) {
            m['byteSize'] = fake.length;
            m['sha256'] = hash;
          }
        }
      }
      final bytes = utf8.encode(jsonEncode(data));
      manifest['data'] = {
        'path': 'data.json',
        'byteSize': bytes.length,
        'sha256': crypto.sha256.convert(bytes).toString(),
      };
      final zip = await _zip(env, {
        ...valid,
        path: fake,
        'data.json': bytes,
        'manifest.json': utf8.encode(jsonEncode(manifest)),
      });
      final target = await HitoCEnv.create();
      final inspection = ok<BackupInspection>(
        await target.backup.inspect(zip.absolute.uri),
      );
      final failure = failed(await target.backup.importZip(inspection.token));
      expect(failure.fieldErrors['backup'], BackupErrors.type);
      expect((await target.rowCounts()).values.every((n) => n == 0), isTrue);
      expect(target.privateFiles().where((f) => f.contains('media/')), isEmpty);
    });

    test('estructura: claves, tipos, referencias y valores', () async {
      Map<String, Object?> firstObservation(Map<String, Object?> d) =>
          (d['observations']! as List).cast<Map<String, Object?>>().firstWhere(
            (o) => o['status'] == 'published',
          );
      final edits = <String, void Function(Map<String, Object?>)>{
        'clave extra': (d) => d['extra'] = 1,
        'sin clave': (d) => d.remove('profile'),
        'observations no lista': (d) => d['observations'] = {},
        'id peligroso': (d) => firstObservation(d)['id'] = '../x',
        'id repetido': (d) => (d['observations']! as List).add(
          (d['observations']! as List).first,
        ),
        'estado': (d) => firstObservation(d)['status'] = 'borrado',
        'categoría': (d) => firstObservation(d)['category'] = 'ovni',
        'título vacío': (d) => firstObservation(d)['title'] = '  ',
        'título número': (d) => firstObservation(d)['title'] = 5,
        'duración': (d) => firstObservation(d)['durationSeconds'] = -1,
        'latitud': (d) =>
            (firstObservation(d)['location']! as Map)['latitude'] = 91.0,
        'fecha': (d) =>
            firstObservation(d)['observedAt'] = '2026-02-31T00:00:00.000Z',
        'fecha sin zona': (d) =>
            firstObservation(d)['observedAt'] = '2026-02-01T00:00:00.000',
        'revisión': (d) => firstObservation(d)['revision'] = 0,
        'actualizada antes de creada': (d) =>
            firstObservation(d)['updatedAt'] = '2001-01-01T00:00:00.000Z',
        'adjunto inexistente': (d) =>
            firstObservation(d)['media'] = ['no-existe'],
        'adjunto sin dueño': (d) => firstObservation(d)['media'] = <String>[],
        'adjunto repetido': (d) {
          final media = firstObservation(d)['media']! as List;
          firstObservation(d)['media'] = [...media, media.first];
        },
        'perfil con audio': (d) =>
            (d['profile']! as Map)['photoMediaId'] = (d['media']! as List)
                .cast<Map<String, Object?>>()
                .firstWhere((m) => m['kind'] == 'audio')['id'],
        'perfil largo': (d) => (d['profile']! as Map)['motto'] = 'x' * 500,
        'manifiesto no coincide': (d) =>
            ((d['media']! as List).first as Map)['byteSize'] = 1,
      };
      for (final MapEntry(key: name, value: edit) in edits.entries) {
        final failure = failed(
          await env.backup.inspect(
            (await _zip(env, _withData(valid, edit))).absolute.uri,
          ),
        );
        expect(failure.code, FailureCode.corruptData, reason: name);
        expect(
          failure.fieldErrors['backup'],
          BackupErrors.structure,
          reason: name,
        );
      }
      await rejects(
        await _zip(env, {...valid, 'manifest.json': utf8.encode('{')}),
        BackupErrors.structure,
      );
      await rejects(
        await _zip(env, {
          ...valid,
          'manifest.json': [0xff, 0xfe],
        }),
        BackupErrors.structure,
      );
    });

    test('expansión acotada: tamaño declarado falso y topes', () async {
      // data.json real de varios MB declarado como pequeño.
      final bomb = await _zip(env, {
        ...valid,
        'data.json': List.filled(4 * 1024 * 1024, 0x20),
      });
      final bytes = bomb.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i + 46 < bytes.length; i++) {
        if (data.getUint32(i, Endian.little) == 0x02014b50) {
          final length = data.getUint16(i + 28, Endian.little);
          final name = ascii.decode(bytes.sublist(i + 46, i + 46 + length));
          if (name == 'data.json') {
            data.setUint32(i + 24, valid['data.json']!.length, Endian.little);
          }
        }
      }
      await rejects(raw(bytes), BackupErrors.size);

      Future<void> limited(BackupLimits limits) async {
        env
          ..limits = limits
          ..rebuildBackup();
        await rejects(
          File('${env.outside.path}/copia.zip'),
          BackupErrors.tooLarge,
        );
      }

      await limited(const BackupLimits(totalBytes: 500));
      await limited(const BackupLimits(entries: 3));
      await limited(const BackupLimits(mediaBytes: 100));
      await limited(const BackupLimits(dataBytes: 100));
      await limited(const BackupLimits(manifestBytes: 100));
    });

    test('ZIP ambiguo: duplicados, enlaces, cifrado y solapes', () async {
      await rejects(
        await _zip(env, {...valid, 'MANIFEST.json': utf8.encode('{}')}),
        BackupErrors.structure,
      );
      final bytes = File('${env.outside.path}/copia.zip').readAsBytesSync();
      Uint8List patch(void Function(ByteData data, int at) edit) {
        final copy = Uint8List.fromList(bytes);
        final data = ByteData.sublistView(copy);
        for (var i = 0; i + 46 < copy.length; i++) {
          if (data.getUint32(i, Endian.little) == 0x02014b50) {
            edit(data, i);
            break;
          }
        }
        return copy;
      }

      await rejects(
        raw(patch((d, i) => d.setUint32(i + 38, 0xa1ff0000, Endian.little))),
        BackupErrors.unsafePath,
      );
      await rejects(
        raw(patch((d, i) => d.setUint16(i + 8, 1, Endian.little))),
        BackupErrors.structure,
      );
      await rejects(
        raw(patch((d, i) => d.setUint16(i + 10, 12, Endian.little))),
        BackupErrors.structure,
      );
      await rejects(
        raw(patch((d, i) => d.setUint32(i + 42, 5, Endian.little))),
        BackupErrors.structure,
      );
      await rejects(
        raw(patch((d, i) => d.setUint32(i + 20, 0xffffffff, Endian.little))),
        BackupErrors.tooLarge,
      );
    });

    test('proveedor de documentos caído', () async {
      env
        ..documents = const _BrokenDocuments()
        ..rebuildBackup();
      final failure = failed(
        await env.backup.inspect(env.outsideUri('copia.zip')),
      );
      expect(failure.code, FailureCode.io);
      expect(env.privateFiles(), filesBefore);
    });
  });

  group('Fallo durante la importación', () {
    for (final step in ['extracted', 'moved', 'inserted']) {
      test('en "$step": sin estado parcial y con reintento posible', () async {
        final source = await HitoCEnv.create();
        await source.seed();
        await _export(source);
        final target = await HitoCEnv.create();
        target.prefix = 'b';
        final own = await target.add(
          target.input(title: 'Propia', media: [await target.stagePhoto()]),
        );
        final before = await target.dump();
        final inspection = ok<BackupInspection>(
          await target.backup.inspect(source.outsideUri('copia.zip')),
        );
        final files = target
            .privateFiles()
            .where((f) => !f.contains('staging'))
            .toList();
        target.onImportStep = (current) {
          if (current == step) {
            throw const FileSystemException('No space left on device');
          }
        };
        final failure = failed(await target.backup.importZip(inspection.token));
        expect(failure.code, FailureCode.storageFull);
        expect(await target.dump(), before);
        expect(
          target.privateFiles().where((f) => !f.contains('staging')),
          files,
        );
        expect(target.gate.isClosed, isFalse);

        target.onImportStep = null;
        expect(
          ok<ImportReport>(await target.backup.importZip(inspection.token))
              .importedObservations,
          2,
        );
        ok(await target.store.getById(own.id));
      });
    }

    test(
      'proceso muerto tras mover archivos: el arranque los limpia',
      () async {
        final env = await HitoCEnv.create();
        env.file('media/photos/huerfana.jpg')
          ..createSync(recursive: true)
          ..writeAsBytesSync([0xff, 0xd8, 0xff]);
        env.file('staging/import-x/backup.zip')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1]);
        await env.restart();
        await env.backup.purgeStaging();
        ok(await env.maintenance.run());
        expect(env.privateFiles(), isEmpty);
      },
    );

    test('token inválido, descartado o bytes cambiados tras revisar', () async {
      final source = await HitoCEnv.create();
      await source.seed();
      await _export(source);
      final target = await HitoCEnv.create();
      Future<BackupInspection> inspect() async => ok<BackupInspection>(
        await target.backup.inspect(source.outsideUri('copia.zip')),
      );
      expect(
        failed(await target.backup.importZip('inventado'))
            .fieldErrors['backup'],
        BackupErrors.expired,
      );
      final first = await inspect();
      final second = await inspect();
      expect(
        failed(await target.backup.importZip(first.token))
            .fieldErrors['backup'],
        BackupErrors.expired,
        reason: 'una revisión nueva invalida la anterior',
      );
      await target.backup.discardInspection(second.token);
      expect(
        failed(await target.backup.importZip(second.token))
            .fieldErrors['backup'],
        BackupErrors.expired,
      );
      expect(target.privateFiles(), isEmpty);

      final third = await inspect();
      final staged = target.support
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('backup.zip'));
      staged.writeAsBytesSync([0], mode: FileMode.append);
      expect(
        failed(await target.backup.importZip(third.token))
            .fieldErrors['backup'],
        BackupErrors.hash,
      );
      expect((await target.rowCounts())['observations'], 0);
    });

    test(
      'una escritura durante la importación se rechaza como ocupado',
      () async {
        final source = await HitoCEnv.create();
        await source.seed();
        await _export(source);
        final target = await HitoCEnv.create();
        final inspection = ok<BackupInspection>(
          await target.backup.inspect(source.outsideUri('copia.zip')),
        );
        final results = <Result<Object?>>[];
        target.onImportStep = (step) async {
          if (step != 'moved') return;
          results
            ..add(
              await target.store.create(
                target.input(),
                status: ObservationStatus.published,
              ),
            )
            // La limpieza no puede confundir lo recién movido con huérfanos.
            ..add(await target.maintenance.run());
        };
        ok(await target.backup.importZip(inspection.token));
        expect(results.map((r) => failed(r).code), [
          FailureCode.busy,
          FailureCode.busy,
        ]);
      },
    );
  });
}
