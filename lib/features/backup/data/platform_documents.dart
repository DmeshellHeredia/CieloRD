import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/platform/cielo_platform.dart';
import '../domain/backup_service.dart';

/// Lectura y escritura del documento elegido. Separada del selector para que
/// el servicio de copias no dependa de la interfaz.
abstract interface class DocumentStore {
  /// Escribe [source] en [destination] y comprueba el tamaño escrito.
  Future<void> write(File source, Uri destination);

  /// Copia [source] a [destination]; falla si supera [maxBytes].
  Future<void> read(Uri source, File destination, {required int maxBytes});

  /// Elimina un destino cuya escritura falló. Con [onlyIfEmpty] solo si está
  /// vacío (recién creado por el selector).
  Future<void> discard(Uri destination, {required bool onlyIfEmpty});
}

/// El documento supera el tope permitido.
final class DocumentTooLarge implements Exception {
  const DocumentTooLarge();
}

/// Documentos `content:` por el canal de Android y `file:` por `dart:io`.
final class PlatformDocuments implements DocumentGateway, DocumentStore {
  const PlatformDocuments([this._platform = const CieloPlatform()]);

  final CieloPlatform _platform;

  @override
  Future<Uri?> createDocument({
    required String suggestedName,
    required String mimeType,
  }) async {
    final uri = await _platform.createDocument(suggestedName, mimeType);
    return uri == null ? null : Uri.parse(uri);
  }

  @override
  Future<Uri?> openDocument({required List<String> mimeTypes}) async {
    final uri = await _platform.openDocument(mimeTypes);
    return uri == null ? null : Uri.parse(uri);
  }

  @override
  Future<void> write(File source, Uri destination) async {
    final expected = await source.length();
    final int written;
    if (destination.isScheme('file')) {
      written = await (await source.copy(destination.toFilePath())).length();
    } else {
      written = await _platform.writeDocument(
        source.path,
        destination.toString(),
      );
    }
    if (written != expected) {
      throw FileSystemException('Wrote $written of $expected bytes.');
    }
  }

  @override
  Future<void> read(
    Uri source,
    File destination, {
    required int maxBytes,
  }) async {
    if (source.isScheme('file')) {
      final file = File(source.toFilePath());
      if (await file.length() > maxBytes) throw const DocumentTooLarge();
      await file.copy(destination.path);
    } else {
      try {
        await _platform.readDocument(
          source.toString(),
          destination.path,
          maxBytes,
        );
      } on PlatformException catch (error) {
        if (error.code == 'too_large') throw const DocumentTooLarge();
        rethrow;
      }
    }
    if (await destination.length() > maxBytes) throw const DocumentTooLarge();
  }

  @override
  Future<void> discard(Uri destination, {required bool onlyIfEmpty}) async {
    if (destination.isScheme('file')) {
      final file = File(destination.toFilePath());
      if (!await file.exists()) return;
      if (onlyIfEmpty && await file.length() > 0) return;
      await file.delete();
    } else {
      await _platform.deleteDocument(
        destination.toString(),
        onlyIfEmpty: onlyIfEmpty,
      );
    }
  }
}
