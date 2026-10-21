import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

const String signatureCacheFolder = 'signatures';

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Builds a file name such as `signature-20261021-153045-123.png`.
///
/// Millisecond precision keeps names unique so files never overwrite
/// each other.
String signatureFileName([DateTime? now]) {
  final t = now ?? DateTime.now();
  final date = '${t.year}${_twoDigits(t.month)}${_twoDigits(t.day)}';
  final time =
      '${_twoDigits(t.hour)}${_twoDigits(t.minute)}'
      '${_twoDigits(t.second)}';
  final millis = t.millisecond.toString().padLeft(3, '0');
  return 'signature-$date-$time-$millis.png';
}

Future<File> writeSignatureToDirectory(
  Uint8List bytes,
  Directory directory, {
  DateTime? now,
}) async {
  await directory.create(recursive: true);
  final file = File('${directory.path}/${signatureFileName(now)}');
  return file.writeAsBytes(bytes, flush: true);
}

Future<Directory> signatureCacheDirectory() async {
  final temp = await getTemporaryDirectory();
  return Directory('${temp.path}/$signatureCacheFolder');
}

Future<File> writeSignatureToTemp(Uint8List bytes) async {
  return writeSignatureToDirectory(bytes, await signatureCacheDirectory());
}

/// Deletes every cached signature in [directory]. Missing directories and
/// files that cannot be removed are ignored.
Future<void> clearSignatureDirectory(Directory directory) async {
  if (!await directory.exists()) return;
  await for (final entity in directory.list()) {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // A file may still be in use by a share target; try again next launch.
    }
  }
}

/// Removes signatures left in the cache by earlier sessions.
Future<void> clearSignatureCache() async {
  try {
    await clearSignatureDirectory(await signatureCacheDirectory());
  } on Exception {
    // Cache cleanup is best effort and must never block the app.
  }
}
