import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

String signatureFileName([Random? random]) {
  return 'signature-${(random ?? Random()).nextInt(10000)}.png';
}

Future<File> writeSignatureToDirectory(
  Uint8List bytes,
  Directory directory, {
  Random? random,
}) async {
  final file = File('${directory.path}/${signatureFileName(random)}');
  return file.writeAsBytes(bytes);
}

Future<File> writeSignatureToTemp(Uint8List bytes) async {
  return writeSignatureToDirectory(bytes, await getTemporaryDirectory());
}
