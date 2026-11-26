import 'dart:async';
import 'dart:ui';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/security/application/app_lock_controller.dart';
import 'package:cielo_rd/features/security/data/device_auth_service.dart';
import 'package:cielo_rd/features/settings/application/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import '../helpers/hito_c_fakes.dart';

final class _Gateway implements DeviceAuthGateway {
  bool supported = true;
  bool result = true;
  Object? error;
  int stops = 0;

  @override
  Future<bool> isDeviceSupported() async {
    if (error != null) throw error!;
    return supported;
  }

  @override
  Future<bool> authenticate(String reason) async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (error != null) throw error!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceAuthService', () {
    test('disponibilidad: con y sin credenciales, y desconocida', () async {
      final gateway = _Gateway();
      final service = DeviceAuthService(gateway);
      expect(await service.availability(), AuthAvailability.available);
      gateway.supported = false;
      expect(await service.availability(), AuthAvailability.noCredentials);
      gateway.error = StateError('canal');
      expect(
        await service.availability(),
        AuthAvailability.unknown,
        reason: 'un error no debe confundirse con "sin PIN"',
      );
    });

    test('éxito y fallo', () async {
      final gateway = _Gateway();
      final service = DeviceAuthService(gateway);
      expect(await service.authenticate('x'), AuthOutcome.success);
      gateway.result = false;
      expect(await service.authenticate('x'), AuthOutcome.failed);
    });

    test(
      'cada código del plugin tiene un resultado y nunca es éxito',
      () async {
        const expected = {
          LocalAuthExceptionCode.userCanceled: AuthOutcome.cancelled,
          LocalAuthExceptionCode.systemCanceled: AuthOutcome.cancelled,
          LocalAuthExceptionCode.timeout: AuthOutcome.cancelled,
          LocalAuthExceptionCode.authInProgress: AuthOutcome.cancelled,
          LocalAuthExceptionCode.userRequestedFallback: AuthOutcome.cancelled,
          LocalAuthExceptionCode.temporaryLockout:
              AuthOutcome.temporarilyLocked,
          LocalAuthExceptionCode.biometricLockout: AuthOutcome.biometricLocked,
          LocalAuthExceptionCode.noCredentialsSet: AuthOutcome.noCredentials,
          LocalAuthExceptionCode.noBiometricsEnrolled:
              AuthOutcome.noCredentials,
          LocalAuthExceptionCode.noBiometricHardware: AuthOutcome.noCredentials,
          LocalAuthExceptionCode.uiUnavailable: AuthOutcome.unavailable,
          LocalAuthExceptionCode.deviceError: AuthOutcome.unavailable,
          LocalAuthExceptionCode.unknownError: AuthOutcome.unavailable,
          LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
              AuthOutcome.unavailable,
        };
        expect(expected.keys.toSet(), LocalAuthExceptionCode.values.toSet());
        for (final entry in expected.entries) {
          final service = DeviceAuthService(
            _Gateway()..error = LocalAuthException(code: entry.key),
          );
          expect(await service.authenticate('x'), entry.value);
        }
        final broken = DeviceAuthService(
          _Gateway()..error = StateError('canal'),
        );
        expect(await broken.authenticate('x'), AuthOutcome.unavailable);
        await broken.cancel();
      },
    );
  });

  group('AppLockController', () {
    late MemorySettings repository;
    late SettingsController settings;
    late FakeAuth auth;
    late List<bool> privacy;

    Future<AppLockController> build({
      bool enabled = false,
      AppFailure? loadFailure,
    }) async {
      repository = MemorySettings(AppSettings(authenticationEnabled: enabled))
        ..getFailure = loadFailure;
      settings = SettingsController(repository: repository);
      await settings.load();
      auth = FakeAuth();
      privacy = [];
      final controller = AppLockController(
        settings: settings,
        auth: auth,
        unlockReason: 'abrir',
        onPrivacyChanged: privacy.add,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('desactivado por defecto: nunca pide nada', () async {
      final lock = await build();
      expect(lock.isLocked, isFalse);
      lock
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);
      await lock.unlock();
      expect(lock.isLocked, isFalse);
      expect(auth.reasons, isEmpty);
      expect(privacy, [false]);
    });

    test('activar exige credenciales y verificarse', () async {
      final lock = await build();
      auth.available = AuthAvailability.noCredentials;
      expect((await lock.enable('activar')).outcome, AuthOutcome.noCredentials);
      expect(auth.reasons, isEmpty);

      auth.available = AuthAvailability.available;
      for (final outcome in AuthOutcome.values) {
        if (outcome == AuthOutcome.success) continue;
        auth.outcome = outcome;
        expect((await lock.enable('activar')).outcome, outcome);
        expect(repository.value.authenticationEnabled, isFalse);
      }
      auth.outcome = AuthOutcome.success;
      expect((await lock.enable('activar')).failure, isNull);
      expect(repository.value.authenticationEnabled, isTrue);
      expect(lock.isLocked, isFalse, reason: 'acaba de verificarse');
      expect(privacy, [false, true]);
    });

    test('desactivar también exige verificarse', () async {
      final lock = await build(enabled: true);
      await lock.unlock();
      auth.outcome = AuthOutcome.cancelled;
      await lock.disable('desactivar');
      expect(repository.value.authenticationEnabled, isTrue);
      auth.outcome = AuthOutcome.success;
      await lock.disable('desactivar');
      expect(repository.value.authenticationEnabled, isFalse);
    });

    test('arranca bloqueada; éxito abre, lo demás no', () async {
      final lock = await build(enabled: true);
      expect(lock.isLocked, isTrue);
      for (final outcome in AuthOutcome.values) {
        if (outcome == AuthOutcome.success) continue;
        auth.outcome = outcome;
        await lock.unlock();
        expect(lock.isLocked, isTrue, reason: outcome.name);
        expect(lock.lastOutcome, outcome);
      }
      auth.outcome = AuthOutcome.success;
      await lock.unlock();
      expect(lock.isLocked, isFalse);
    });

    test('segundo plano bloquea y al volver pide una sola vez', () async {
      final lock = await build(enabled: true);
      await lock.unlock();
      auth
        ..reasons.clear()
        ..outcome = AuthOutcome.cancelled;
      lock
        ..didChangeAppLifecycleState(AppLifecycleState.inactive)
        ..didChangeAppLifecycleState(AppLifecycleState.hidden)
        ..didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(lock.isLocked, isTrue);
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(auth.reasons, ['abrir']);
      expect(lock.isLocked, isTrue);
      // Cancelar no entra en un bucle de diálogos.
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(auth.reasons, ['abrir']);
    });

    test('un aviso del sistema (inactive) no bloquea', () async {
      final lock = await build(enabled: true);
      await lock.unlock();
      lock
        ..didChangeAppLifecycleState(AppLifecycleState.inactive)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.isLocked, isFalse);
    });

    test('la pantalla de PIN del sistema no vuelve a bloquear', () async {
      final lock = await build(enabled: true);
      auth.pending = Completer<AuthOutcome>();
      final unlocking = lock.unlock();
      expect(lock.isAuthenticating, isTrue);
      lock
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);
      auth.pending!.complete(AuthOutcome.success);
      await unlocking;
      expect(lock.isLocked, isFalse);
      expect(auth.reasons, hasLength(1));
    });

    test('pulsar dos veces no abre dos diálogos', () async {
      final lock = await build(enabled: true);
      auth.pending = Completer<AuthOutcome>();
      final first = lock.unlock();
      await lock.unlock();
      auth.pending!.complete(AuthOutcome.success);
      await first;
      expect(auth.reasons, hasLength(1));
    });

    test(
      'sin PIN en el teléfono: salida explícita, solo si es seguro',
      () async {
        final lock = await build(enabled: true);
        expect(
          (await lock.openWithoutCredentials())?.code,
          FailureCode.permissionDenied,
        );
        // Sin un intento previo que lo confirme, tampoco se abre.
        auth.available = AuthAvailability.noCredentials;
        expect(
          (await lock.openWithoutCredentials())?.code,
          FailureCode.permissionDenied,
        );
        expect(lock.isLocked, isTrue);
        auth.available = AuthAvailability.available;
        auth.outcome = AuthOutcome.noCredentials;
        await lock.unlock();
        expect(
          lock.credentialsMissing,
          isFalse,
          reason: 'el teléfono dice que sí hay credenciales',
        );
        auth.available = AuthAvailability.unknown;
        await lock.unlock();
        expect(lock.credentialsMissing, isFalse);

        auth.available = AuthAvailability.noCredentials;
        await lock.unlock();
        expect(lock.credentialsMissing, isTrue);
        expect(lock.isLocked, isTrue, reason: 'no se abre sola');
        auth.available = AuthAvailability.available;
        expect(
          (await lock.openWithoutCredentials())?.code,
          FailureCode.permissionDenied,
        );
        expect(lock.isLocked, isTrue);
        auth.available = AuthAvailability.noCredentials;
        expect(await lock.openWithoutCredentials(), isNull);
        expect(lock.isLocked, isFalse);
        expect(repository.value.authenticationEnabled, isFalse);
      },
    );

    test('si desactivar no se puede guardar, sigue bloqueada', () async {
      final lock = await build(enabled: true);
      auth
        ..outcome = AuthOutcome.noCredentials
        ..available = AuthAvailability.noCredentials;
      await lock.unlock();
      repository.saveFailure = AppFailure(FailureCode.storageFull);
      expect(await lock.openWithoutCredentials(), isNotNull);
      expect(lock.isLocked, isTrue);
    });

    test(
      'preferencias ilegibles al arrancar: al leerlas queda bloqueada',
      () async {
        final lock = await build(
          enabled: true,
          loadFailure: AppFailure(FailureCode.persistence),
        );
        expect(settings.loadFailure, isNotNull);
        repository.getFailure = null;
        await settings.load();
        expect(lock.isLocked, isTrue);
      },
    );

    test('Borrar Todo restablece y desbloquea', () async {
      final lock = await build(enabled: true);
      await lock.unlock();
      settings.resetToDefaults();
      expect(lock.isLocked, isFalse);
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(lock.isLocked, isFalse);
      expect(privacy.last, isFalse);
    });
  });
}
