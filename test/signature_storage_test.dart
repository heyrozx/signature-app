import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_signature/signature_storage.dart';

class _FixedRandom implements Random {
  final int value;
  _FixedRandom(this.value);

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('signatureFileName', () {
    test('uses the signature-<n>.png pattern', () {
      expect(signatureFileName(_FixedRandom(42)), 'signature-42.png');
    });

    test('keeps the number below 10000', () {
      expect(signatureFileName(_FixedRandom(12345)), 'signature-2345.png');
    });

    test('produces a valid name without an explicit Random', () {
      expect(signatureFileName(), matches(RegExp(r'^signature-\d{1,4}\.png$')));
    });
  });

  group('writeSignatureToDirectory', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('signature_test');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('writes the exact PNG bytes into the directory', () async {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

      final file = await writeSignatureToDirectory(
        bytes,
        dir,
        random: _FixedRandom(7),
      );

      expect(file.path, '${dir.path}/signature-7.png');
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
    });

    test('overwrites an existing file with the same name', () async {
      await writeSignatureToDirectory(
        Uint8List.fromList([1, 1, 1]),
        dir,
        random: _FixedRandom(1),
      );
      final file = await writeSignatureToDirectory(
        Uint8List.fromList([2]),
        dir,
        random: _FixedRandom(1),
      );

      expect(await file.readAsBytes(), [2]);
      expect(dir.listSync(), hasLength(1));
    });
  });
}
