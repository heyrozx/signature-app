import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_signature/signature_storage.dart';

void main() {
  group('signatureFileName', () {
    test('uses a zero-padded timestamp', () {
      expect(
        signatureFileName(DateTime(2026, 1, 2, 3, 4, 5, 6)),
        'signature-20260102-030405-006.png',
      );
    });

    test('differs for saves within the same second', () {
      final a = signatureFileName(DateTime(2026, 10, 21, 15, 30, 45, 1));
      final b = signatureFileName(DateTime(2026, 10, 21, 15, 30, 45, 2));
      expect(a, isNot(b));
    });

    test('produces a valid name without an explicit time', () {
      expect(
        signatureFileName(),
        matches(RegExp(r'^signature-\d{8}-\d{6}-\d{3}\.png$')),
      );
    });
  });

  group('writeSignatureToDirectory', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('signature_test');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('writes the exact PNG bytes into the directory', () async {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      final now = DateTime(2026, 10, 21, 15, 30, 45, 123);

      final file = await writeSignatureToDirectory(bytes, root, now: now);

      expect(file.path, '${root.path}/signature-20261021-153045-123.png');
      expect(await file.readAsBytes(), bytes);
    });

    test('creates the directory when it does not exist', () async {
      final nested = Directory('${root.path}/$signatureCacheFolder');

      final file = await writeSignatureToDirectory(
        Uint8List.fromList([1]),
        nested,
      );

      expect(await nested.exists(), isTrue);
      expect(await file.exists(), isTrue);
    });

    test('keeps earlier signatures instead of overwriting them', () async {
      await writeSignatureToDirectory(
        Uint8List.fromList([1]),
        root,
        now: DateTime(2026, 1, 1, 0, 0, 0, 1),
      );
      await writeSignatureToDirectory(
        Uint8List.fromList([2]),
        root,
        now: DateTime(2026, 1, 1, 0, 0, 0, 2),
      );

      expect(root.listSync(), hasLength(2));
    });
  });

  group('clearSignatureDirectory', () {
    test('removes every cached signature', () async {
      final root = await Directory.systemTemp.createTemp('signature_test');
      addTearDown(() => root.delete(recursive: true));
      for (var i = 0; i < 3; i++) {
        await writeSignatureToDirectory(
          Uint8List.fromList([i]),
          root,
          now: DateTime(2026, 1, 1, 0, 0, 0, i),
        );
      }

      await clearSignatureDirectory(root);

      expect(await root.exists(), isTrue);
      expect(root.listSync(), isEmpty);
    });

    test('ignores a directory that does not exist', () async {
      final missing = Directory(
        '${Directory.systemTemp.path}/does-not-exist-${DateTime.now().microsecondsSinceEpoch}',
      );

      await expectLater(clearSignatureDirectory(missing), completes);
    });
  });
}
