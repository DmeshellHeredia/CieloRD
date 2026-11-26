import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// ZIP rechazado. [reason] es un código estable de `BackupErrors`.
final class ZipRejected implements Exception {
  const ZipRejected(this.reason, [this.detail = '']);
  final String reason;
  final String detail;

  @override
  String toString() =>
      'ZipRejected($reason${detail.isEmpty ? '' : ': $detail'})';
}

/// CRC-32 (IEEE 802.3) incremental.
final class Crc32 {
  static final Uint32List _table = () {
    final table = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      table[n] = c;
    }
    return table;
  }();

  int _state = 0xffffffff;

  void add(List<int> bytes) {
    var c = _state;
    for (final b in bytes) {
      c = _table[(c ^ b) & 0xff] ^ (c >>> 8);
    }
    _state = c;
  }

  int get value => (_state ^ 0xffffffff) & 0xffffffff;
}

final class ZipEntry {
  const ZipEntry({
    required this.name,
    required this.method,
    required this.crc32,
    required this.compressedSize,
    required this.size,
    required this.headerOffset,
  });
  final String name;
  final int method;
  final int crc32;
  final int compressedSize;
  final int size;
  final int headerOffset;
}

/// Bytes ya verificados de una entrada (tamaño y CRC comprobados).
final class ZipDigest {
  const ZipDigest({
    required this.size,
    required this.sha256,
    required this.head,
  });
  final int size;
  final String sha256;

  /// Primeros bytes, para comprobar la firma del tipo de archivo.
  final Uint8List head;
}

/// Lector deliberadamente estricto: admite solo lo que escribe CieloRD y sus
/// equivalentes sin ambigüedad. Rechaza ZIP64, cifrado, varios discos, enlaces
/// simbólicos, nombres duplicados y entradas solapadas. Nunca descomprime más
/// de lo declarado.
final class StrictZipReader {
  StrictZipReader._(this._file, this.entries);

  final File _file;
  final Map<String, ZipEntry> entries;

  static const int _maxDirectoryBytes = 8 * 1024 * 1024;

  static Future<StrictZipReader> open(
    File file, {
    required int maxEntries,
    required int maxTotalBytes,
  }) async {
    final raf = await file.open();
    try {
      final length = await raf.length();
      if (length < 22) throw const ZipRejected('not_a_zip', 'too short');
      final tailLength = length < 65557 ? length : 65557;
      await raf.setPosition(length - tailLength);
      final tail = await raf.read(tailLength);
      final tailData = ByteData.sublistView(tail);
      var end = -1;
      for (var i = tailLength - 22; i >= 0; i--) {
        if (tailData.getUint32(i, Endian.little) == 0x06054b50 &&
            i + 22 + tailData.getUint16(i + 20, Endian.little) == tailLength) {
          end = i;
          break;
        }
      }
      if (end < 0) throw const ZipRejected('not_a_zip', 'no end record');
      int u16(int o) => tailData.getUint16(end + o, Endian.little);
      int u32(int o) => tailData.getUint32(end + o, Endian.little);
      final count = u16(10);
      final directorySize = u32(12);
      final directoryOffset = u32(16);
      if (u16(4) != 0 || u16(6) != 0 || u16(8) != count) {
        throw const ZipRejected('invalid_structure', 'multiple disks');
      }
      if (count == 0xffff ||
          directorySize == 0xffffffff ||
          directoryOffset == 0xffffffff) {
        throw const ZipRejected('too_large', 'zip64');
      }
      if (count > maxEntries || directorySize > _maxDirectoryBytes) {
        throw const ZipRejected('too_large', 'entries');
      }
      final endPosition = length - tailLength + end;
      if (directoryOffset + directorySize != endPosition) {
        throw const ZipRejected('invalid_structure', 'directory bounds');
      }
      await raf.setPosition(directoryOffset);
      final directory = await raf.read(directorySize);
      if (directory.length != directorySize) {
        throw const ZipRejected('invalid_structure', 'truncated directory');
      }
      final entries = _parseDirectory(directory, count, maxTotalBytes);
      await _checkLayout(raf, entries.values, directoryOffset);
      return StrictZipReader._(file, Map.unmodifiable(entries));
    } finally {
      await raf.close();
    }
  }

  static Map<String, ZipEntry> _parseDirectory(
    Uint8List bytes,
    int count,
    int maxTotalBytes,
  ) {
    final data = ByteData.sublistView(bytes);
    final entries = <String, ZipEntry>{};
    final seen = <String>{};
    var total = 0;
    var at = 0;
    for (var n = 0; n < count; n++) {
      if (at + 46 > bytes.length ||
          data.getUint32(at, Endian.little) != 0x02014b50) {
        throw const ZipRejected('invalid_structure', 'directory entry');
      }
      int u16(int o) => data.getUint16(at + o, Endian.little);
      int u32(int o) => data.getUint32(at + o, Endian.little);
      final flags = u16(8);
      final method = u16(10);
      final compressed = u32(20);
      final size = u32(24);
      final nameLength = u16(28);
      final next = at + 46 + nameLength + u16(30) + u16(32);
      if (next > bytes.length || nameLength == 0) {
        throw const ZipRejected('invalid_structure', 'entry bounds');
      }
      final name = _safeName(bytes.sublist(at + 46, at + 46 + nameLength));
      if (flags & 0x2041 != 0) {
        throw ZipRejected('invalid_structure', 'encrypted: $name');
      }
      if (method != 0 && method != 8) {
        throw ZipRejected('invalid_structure', 'method $method: $name');
      }
      if (u16(34) != 0) throw const ZipRejected('invalid_structure', 'disk');
      if ((u32(38) >>> 16) & 0xf000 == 0xa000) {
        throw ZipRejected('unsafe_path', 'symlink: $name');
      }
      if (compressed == 0xffffffff || size == 0xffffffff) {
        throw ZipRejected('too_large', name);
      }
      if (method == 0 && compressed != size) {
        throw ZipRejected('size_mismatch', name);
      }
      total += size;
      if (total > maxTotalBytes) throw const ZipRejected('too_large', 'total');
      if (!seen.add(name.toLowerCase())) {
        throw ZipRejected('invalid_structure', 'duplicate: $name');
      }
      entries[name] = ZipEntry(
        name: name,
        method: method,
        crc32: u32(16),
        compressedSize: compressed,
        size: size,
        headerOffset: u32(42),
      );
      at = next;
    }
    if (at != bytes.length) {
      throw const ZipRejected('invalid_structure', 'trailing directory data');
    }
    return entries;
  }

  /// ASCII imprimible, relativa, sin `..`, `.`, `\`, `:` ni segmentos vacíos.
  static String _safeName(List<int> bytes) {
    if (bytes.any((b) => b < 0x20 || b > 0x7e)) {
      throw const ZipRejected('unsafe_path', 'non printable name');
    }
    final name = ascii.decode(bytes);
    final segments = name.split('/');
    if (name.contains('\\') ||
        name.contains(':') ||
        segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw ZipRejected('unsafe_path', name);
    }
    return name;
  }

  /// Los encabezados locales coinciden con el directorio y no se solapan.
  static Future<void> _checkLayout(
    RandomAccessFile raf,
    Iterable<ZipEntry> entries,
    int limit,
  ) async {
    final sorted = entries.toList()
      ..sort((a, b) => a.headerOffset.compareTo(b.headerOffset));
    var free = 0;
    for (final entry in sorted) {
      if (entry.headerOffset < free) {
        throw ZipRejected('invalid_structure', 'overlap: ${entry.name}');
      }
      free = await _dataOffset(raf, entry) + entry.compressedSize;
      if (free > limit) {
        throw ZipRejected('invalid_structure', 'out of bounds: ${entry.name}');
      }
    }
  }

  static Future<int> _dataOffset(RandomAccessFile raf, ZipEntry entry) async {
    await raf.setPosition(entry.headerOffset);
    final header = await raf.read(30);
    if (header.length != 30) {
      throw ZipRejected('invalid_structure', 'header: ${entry.name}');
    }
    final data = ByteData.sublistView(header);
    final nameLength = data.getUint16(26, Endian.little);
    if (data.getUint32(0, Endian.little) != 0x04034b50 ||
        data.getUint16(6, Endian.little) & 0x2041 != 0 ||
        data.getUint16(8, Endian.little) != entry.method) {
      throw ZipRejected('invalid_structure', 'header: ${entry.name}');
    }
    final name = await raf.read(nameLength);
    if (name.length != nameLength ||
        name.any((b) => b > 0x7e) ||
        ascii.decode(name) != entry.name) {
      throw ZipRejected('invalid_structure', 'header name: ${entry.name}');
    }
    return entry.headerOffset +
        30 +
        nameLength +
        data.getUint16(28, Endian.little);
  }

  /// Recorre la entrada comprobando tamaño y CRC. Escribe en [output] si se
  /// indica; si algo falla, el llamador elimina el archivo parcial.
  Future<ZipDigest> verify(String name, {File? output}) async {
    final entry = entries[name]!;
    final raf = await _file.open();
    final IOSink? sink = output?.openWrite();
    final crc = Crc32();
    final hash = _HashSink();
    final hasher = sha256.startChunkedConversion(hash);
    final head = BytesBuilder();
    final pending = <List<int>>[];
    var size = 0;

    void accept(List<int> chunk) {
      size += chunk.length;
      if (size > entry.size) throw ZipRejected('size_mismatch', name);
      crc.add(chunk);
      hasher.add(chunk);
      if (head.length < 16) {
        final missing = 16 - head.length;
        head.add(chunk.length <= missing ? chunk : chunk.sublist(0, missing));
      }
      if (sink != null) pending.add(chunk);
    }

    final ByteConversionSink? inflater = entry.method == 8
        ? ZLibDecoder(raw: true).startChunkedConversion(_ChunkSink(accept))
        : null;
    try {
      var offset = await _dataOffset(raf, entry);
      await raf.setPosition(offset);
      var remaining = entry.compressedSize;
      while (remaining > 0) {
        final chunk = await raf.read(remaining < 16384 ? remaining : 16384);
        if (chunk.isEmpty) throw ZipRejected('invalid_structure', name);
        remaining -= chunk.length;
        offset += chunk.length;
        if (inflater == null) {
          accept(chunk);
        } else {
          inflater.add(chunk);
        }
        if (sink != null && pending.isNotEmpty) {
          pending.forEach(sink.add);
          pending.clear();
          await sink.flush();
        }
      }
      inflater?.close();
      if (sink != null && pending.isNotEmpty) {
        pending.forEach(sink.add);
        pending.clear();
      }
      if (size != entry.size) throw ZipRejected('size_mismatch', name);
      if (crc.value != entry.crc32) throw ZipRejected('hash_mismatch', name);
      hasher.close();
      return ZipDigest(
        size: size,
        sha256: hash.value.toString(),
        head: head.toBytes(),
      );
    } on FormatException {
      throw ZipRejected('invalid_structure', 'deflate: $name');
    } finally {
      await raf.close();
      if (sink != null) {
        await sink.flush();
        await sink.close();
      }
    }
  }

  /// Entrada pequeña completa en memoria, verificada.
  Future<(Uint8List, ZipDigest)> readAll(
    String name, {
    required int maxBytes,
    required Directory staging,
  }) async {
    if (entries[name]!.size > maxBytes) throw ZipRejected('too_large', name);
    final file = File('${staging.path}/$name.tmp');
    try {
      final digest = await verify(name, output: file);
      return (await file.readAsBytes(), digest);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}

final class _ChunkSink extends ByteConversionSink {
  _ChunkSink(this._onChunk);
  final void Function(List<int> chunk) _onChunk;

  @override
  void add(List<int> chunk) => _onChunk(chunk);

  @override
  void close() {}
}

final class _HashSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Escritor ZIP mínimo. Los adjuntos (ya comprimidos) se almacenan tal cual;
/// el JSON se comprime. Todo en un único recorrido con memoria constante.
final class StreamingZipWriter {
  StreamingZipWriter._(this._raf, this._time, this._date);

  final RandomAccessFile _raf;
  final int _time;
  final int _date;
  final List<ZipEntry> _entries = [];

  static Future<StreamingZipWriter> create(
    File file,
    DateTime timestamp,
  ) async {
    final t = timestamp.toUtc();
    return StreamingZipWriter._(
      await file.open(mode: FileMode.write),
      (t.hour << 11) | (t.minute << 5) | (t.second >> 1),
      ((t.year.clamp(1980, 2107) - 1980) << 9) | (t.month << 5) | t.day,
    );
  }

  /// Almacena [source] y devuelve el tamaño y SHA-256 realmente escritos.
  Future<({int size, String sha256})> addFile(String name, File source) async {
    final headerOffset = await _raf.position();
    await _raf.writeFrom(_localHeader(name, 0, 0, 0, 0));
    final crc = Crc32();
    final hash = _HashSink();
    final hasher = sha256.startChunkedConversion(hash);
    var size = 0;
    await for (final chunk in source.openRead()) {
      crc.add(chunk);
      hasher.add(chunk);
      size += chunk.length;
      await _raf.writeFrom(chunk);
    }
    hasher.close();
    final dataEnd = await _raf.position();
    await _raf.setPosition(headerOffset);
    await _raf.writeFrom(_localHeader(name, 0, crc.value, size, size));
    await _raf.setPosition(dataEnd);
    _entries.add(
      ZipEntry(
        name: name,
        method: 0,
        crc32: crc.value,
        compressedSize: size,
        size: size,
        headerOffset: headerOffset,
      ),
    );
    return (size: size, sha256: hash.value.toString());
  }

  /// Descarta la última entrada si su archivo falló a mitad de lectura.
  Future<int> position() => _raf.position();

  Future<void> rewind(int position) async {
    await _raf.truncate(position);
    await _raf.setPosition(position);
  }

  Future<void> addBytes(String name, List<int> bytes) async {
    final headerOffset = await _raf.position();
    final compressed = ZLibEncoder(raw: true, level: 6).convert(bytes);
    final crc = (Crc32()..add(bytes)).value;
    await _raf.writeFrom(
      _localHeader(name, 8, crc, compressed.length, bytes.length),
    );
    await _raf.writeFrom(compressed);
    _entries.add(
      ZipEntry(
        name: name,
        method: 8,
        crc32: crc,
        compressedSize: compressed.length,
        size: bytes.length,
        headerOffset: headerOffset,
      ),
    );
  }

  Future<void> finish() async {
    final start = await _raf.position();
    for (final entry in _entries) {
      await _raf.writeFrom(_directoryEntry(entry));
    }
    final end = await _raf.position();
    final record = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, _entries.length, Endian.little)
      ..setUint16(10, _entries.length, Endian.little)
      ..setUint32(12, end - start, Endian.little)
      ..setUint32(16, start, Endian.little);
    await _raf.writeFrom(record.buffer.asUint8List());
    await _raf.flush();
    await _raf.close();
  }

  Future<void> abort() => _raf.close();

  Uint8List _localHeader(
    String name,
    int method,
    int crc,
    int compressed,
    int size,
  ) {
    final nameBytes = ascii.encode(name);
    final data = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(8, method, Endian.little)
      ..setUint16(10, _time, Endian.little)
      ..setUint16(12, _date, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, compressed, Endian.little)
      ..setUint32(22, size, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little);
    return Uint8List.fromList([...data.buffer.asUint8List(), ...nameBytes]);
  }

  Uint8List _directoryEntry(ZipEntry e) {
    final nameBytes = ascii.encode(e.name);
    final data = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(10, e.method, Endian.little)
      ..setUint16(12, _time, Endian.little)
      ..setUint16(14, _date, Endian.little)
      ..setUint32(16, e.crc32, Endian.little)
      ..setUint32(20, e.compressedSize, Endian.little)
      ..setUint32(24, e.size, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, e.headerOffset, Endian.little);
    return Uint8List.fromList([...data.buffer.asUint8List(), ...nameBytes]);
  }
}
