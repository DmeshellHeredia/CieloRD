import 'package:flutter/services.dart';

/// Canal propio y mínimo con Android: selector de documentos del sistema
/// (SAF), limpieza de preferencias de plugins y privacidad en Recientes.
/// Ver `MainActivity.kt`.
final class CieloPlatform {
  const CieloPlatform([
    this._channel = const MethodChannel('com.dmeshell.cielo_rd/platform'),
  ]);

  final MethodChannel _channel;

  /// Abre "Guardar como…". `null` si se canceló.
  Future<String?> createDocument(String suggestedName, String mimeType) =>
      _channel.invokeMethod<String>('createDocument', {
        'name': suggestedName,
        'mimeType': mimeType,
      });

  /// Abre el selector de archivos. `null` si se canceló.
  Future<String?> openDocument(List<String> mimeTypes) =>
      _channel.invokeMethod<String>('openDocument', {'mimeTypes': mimeTypes});

  /// Copia un archivo privado al documento. Devuelve los bytes escritos.
  Future<int> writeDocument(String path, String uri) async =>
      await _channel.invokeMethod<int>('writeDocument', {
        'path': path,
        'uri': uri,
      }) ??
      -1;

  /// Copia el documento a un archivo privado, con tope. Devuelve los bytes.
  Future<int> readDocument(String uri, String path, int maxBytes) async =>
      await _channel.invokeMethod<int>('readDocument', {
        'uri': uri,
        'path': path,
        'maxBytes': maxBytes,
      }) ??
      -1;

  /// Elimina un documento cuya escritura falló; con [onlyIfEmpty], solo si
  /// mide cero bytes.
  Future<void> deleteDocument(String uri, {required bool onlyIfEmpty}) =>
      _channel.invokeMethod<void>('deleteDocument', {
        'uri': uri,
        'onlyIfEmpty': onlyIfEmpty,
      });

  /// Vacía las SharedPreferences privadas que crean los plugins.
  Future<void> clearPreferences() =>
      _channel.invokeMethod<void>('clearPreferences');

  /// Oculta el contenido en Recientes (Android 13 o posterior).
  Future<void> setRecentsPrivacy(bool hidden) =>
      _channel.invokeMethod<void>('setRecentsPrivacy', {'hidden': hidden});
}
