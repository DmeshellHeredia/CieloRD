import 'dart:async';

/// Se intentó escribir mientras una operación exclusiva (exportar, importar o
/// borrar todo) tenía la puerta cerrada. Los adaptadores la traducen a
/// `FailureCode.busy`.
final class WriteGateClosed implements Exception {
  const WriteGateClosed();

  @override
  String toString() => 'WriteGateClosed: exclusive operation in progress.';
}

/// Puerta compartida por todo lo que escribe datos privados.
///
/// * [write]: escritura normal; pueden coexistir varias.
/// * [exclusive]: cierra la puerta a escrituras nuevas, espera a que terminen
///   las que ya estaban dentro y ejecuta la operación en solitario.
///
/// No es reentrante: dentro de [exclusive] no se debe llamar a [write].
final class WriteGate {
  int _active = 0;
  bool _exclusive = false;
  Completer<void>? _drained;

  bool get isClosed => _exclusive;

  Future<T> write<T>(Future<T> Function() action) async {
    if (_exclusive) throw const WriteGateClosed();
    _active++;
    try {
      return await action();
    } finally {
      if (--_active == 0) {
        _drained?.complete();
        _drained = null;
      }
    }
  }

  Future<T> exclusive<T>(Future<T> Function() action) async {
    if (_exclusive) throw const WriteGateClosed();
    _exclusive = true;
    try {
      if (_active > 0) await (_drained ??= Completer<void>()).future;
      return await action();
    } finally {
      _exclusive = false;
    }
  }
}
