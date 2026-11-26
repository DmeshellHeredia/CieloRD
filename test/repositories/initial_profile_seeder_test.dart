import 'dart:io';
import 'dart:typed_data';

import 'package:cielo_rd/app/app_identity.dart';
import 'package:cielo_rd/features/profile/application/initial_profile_seeder.dart';
import 'package:cielo_rd/features/profile/domain/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../helpers/hito_c_env.dart';

InitialProfileSeeder _seeder(HitoCEnv env) => InitialProfileSeeder(
  repository: env.profile,
  media: env.media,
  supportDirectory: () async => env.support,
  profile: AppIdentity.profile,
  photoAsset: AppIdentity.profilePhotoJpegAsset,
  photoThumbnailAsset: AppIdentity.profilePhotoThumbnailAsset,
  loadAsset: (String path) async =>
      Uint8List.fromList(await File(path).readAsBytes()),
);

void main() {
  test('siembra una sola vez el perfil y su foto privada offline', () async {
    final env = await HitoCEnv.create();

    ok(await _seeder(env).run());

    final ObserverProfile stored = ok(await env.profile.get())!;
    expect(stored.firstName, 'Michael Dmeshell');
    expect(stored.lastName, 'Sanchez Heredia');
    expect(stored.fullName, 'Michael Dmeshell Sanchez Heredia');
    expect(stored.studentId, '2024-0063');
    expect(stored.motto, '«¡Quiero vivir!» — Nico Robin');
    expect(stored.photoMediaId, isNotNull);
    final String photoPath = ok(
      await env.media.resolveLocalPath(stored.photoMediaId!),
    );
    final bytes = await File(photoPath).readAsBytes();
    expect(image.decodeImage(bytes), isNotNull);
    expect(
      File('${env.support.path}/${InitialProfileSeeder.markerName}')
          .existsSync(),
      isTrue,
    );

    ok(await _seeder(env).run());
    expect((await env.rowCounts())['observer_profile'], 1);
    expect((await env.rowCounts())['media_files'], 1);
  });

  test('un perfil existente nunca se sobrescribe', () async {
    final env = await HitoCEnv.create();
    ok(
      await env.profile.save(
        const ObserverProfile(
          firstName: 'Perfil',
          lastName: 'Editado',
          studentId: 'PERSONAL',
          motto: 'Mi frase',
        ),
      ),
    );

    ok(await _seeder(env).run());

    final ObserverProfile stored = ok(await env.profile.get())!;
    expect(stored.fullName, 'Perfil Editado');
    expect(stored.studentId, 'PERSONAL');
    expect((await env.rowCounts())['media_files'], 0);
  });

  test(
    'Borrar Todo elimina identidad y el marcador impide resiembra',
    () async {
      final env = await HitoCEnv.create();
      ok(await _seeder(env).run());
      final marker = File(
        '${env.support.path}/${InitialProfileSeeder.markerName}',
      );
      expect(marker.existsSync(), isTrue);

      final report = ok(await env.eraser().eraseAll());
      expect(report.isComplete, isTrue);
      expect(
        marker.existsSync(),
        isTrue,
        reason: 'el marcador no contiene PII',
      );
      await env.restart();
      ok(await _seeder(env).run());

      expect(ok(await env.profile.get()), isNull);
      expect((await env.rowCounts())['media_files'], 0);

      ok(
        await env.profile.save(
          const ObserverProfile(firstName: 'Perfil recreado'),
        ),
      );
      expect(ok(await env.profile.get())!.firstName, 'Perfil recreado');
    },
  );
}
