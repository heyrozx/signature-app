import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/result_signature.dart';

const _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

// 1x1 transparent PNG.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0xE9, 0xFA, 0xDC, 0xD8, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('saveSignature', () {
    test('reports success and uses a timestamped file name', () async {
      String? savedName;
      Uint8List? savedBytes;

      final result = await saveSignature(
        _png,
        now: DateTime(2026, 10, 21, 9, 8, 7, 6),
        saveFile: ({required fileName, required bytes}) async {
          savedName = fileName;
          savedBytes = bytes;
          return '/storage/$fileName';
        },
      );

      expect(result, SaveResult.saved);
      expect(savedName, 'signature-20261021-090807-006.png');
      expect(savedBytes, _png);
    });

    test('treats a dismissed save dialog as cancelled', () async {
      final result = await saveSignature(
        _png,
        saveFile: ({required fileName, required bytes}) =>
            throw PlatformException(code: 'CANCELLED'),
      );
      expect(result, SaveResult.cancelled);
    });

    test('reports platform errors as failures', () async {
      final result = await saveSignature(
        _png,
        saveFile: ({required fileName, required bytes}) =>
            throw PlatformException(code: 'security_exception'),
      );
      expect(result, SaveResult.failed);
    });

    test('reports unexpected errors as failures', () async {
      final result = await saveSignature(
        _png,
        saveFile: ({required fileName, required bytes}) =>
            throw const FileSystemException('disk full'),
      );
      expect(result, SaveResult.failed);
    });
  });

  test('saveResultMessage has a message for every result', () {
    expect(
      saveResultMessage(SaveResult.saved),
      'Signature successfully saved!',
    );
    expect(saveResultMessage(SaveResult.cancelled), 'Save cancelled');
    expect(saveResultMessage(SaveResult.failed), 'Failed to save signature');
  });

  group('ResultSignature page', () {
    late List<String> toasts;

    setUp(() {
      toasts = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_toastChannel, (call) async {
            toasts.add((call.arguments as Map)['msg'] as String);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_toastChannel, null);
    });

    Future<void> settleToasts(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 2));

    testWidgets('saves automatically once and shows the preview', (
      tester,
    ) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ResultSignature(
            image: _png,
            showAd: false,
            saveFile: ({required fileName, required bytes}) async {
              saves++;
              return fileName;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(saves, 1);
      expect(toasts, ['Signature successfully saved!']);
      expect(find.byType(Image), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('a cancelled save can be retried with the Save button', (
      tester,
    ) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ResultSignature(
            image: _png,
            showAd: false,
            saveFile: ({required fileName, required bytes}) async {
              attempts++;
              if (attempts == 1) throw PlatformException(code: 'CANCELLED');
              return fileName;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(toasts, ['Save cancelled']);

      await tester.tap(find.text(' Save'));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(toasts.last, 'Signature successfully saved!');
      await settleToasts(tester);
    });

    testWidgets('share writes a file and hands it to the share sheet', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('result_test'),
      ))!;
      addTearDown(() => dir.deleteSync(recursive: true));
      File? shared;

      await tester.pumpWidget(
        MaterialApp(
          home: ResultSignature(
            image: _png,
            showAd: false,
            saveFile: ({required fileName, required bytes}) async => fileName,
            writeTempFile: (bytes) async {
              final file = File('${dir.path}/shared.png');
              file.writeAsBytesSync(bytes);
              return file;
            },
            shareFile: (file) async => shared = file,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(' Share Signature'));
      await tester.pump();
      await tester.pump();

      expect(shared, isNotNull);
      expect(shared!.readAsBytesSync(), _png);
      await settleToasts(tester);
    });

    testWidgets('share failures show a message instead of crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultSignature(
            image: _png,
            showAd: false,
            saveFile: ({required fileName, required bytes}) async => fileName,
            writeTempFile: (bytes) async =>
                throw const FileSystemException('no space'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(' Share Signature'));
      await tester.pump();
      await tester.pump();

      expect(toasts.last, 'Unable to share your signature');
      await settleToasts(tester);
    });

    testWidgets('leaving before the save finishes does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultSignature(
            image: _png,
            showAd: false,
            saveFile: ({required fileName, required bytes}) =>
                Future.delayed(const Duration(seconds: 1), () => fileName),
          ),
        ),
      );
      await tester.pump();

      // Replace the page while the save is still pending.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(toasts, isEmpty);
    });
  });
}
