import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/app_strings.dart';
import 'package:simple_signature/result_signature.dart';

const _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

// 1x1 PNGs: a transparent pixel and a white pixel.
final Uint8List _transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
final Uint8List _whitePng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0x0F, 0x04, 0x00,
  0x09, 0xFB, 0x03, 0xFD, 0xFB, 0x5E, 0x6B, 0x2B, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _en = AppStrings('en');

Future<String> _noSave({
  required String fileName,
  required Uint8List bytes,
}) async => fileName;

void main() {
  group('saveSignature', () {
    test('reports success and uses a timestamped file name', () async {
      String? savedName;
      Uint8List? savedBytes;

      final result = await saveSignature(
        _transparentPng,
        now: DateTime(2026, 10, 21, 9, 8, 7, 6),
        saveFile: ({required fileName, required bytes}) async {
          savedName = fileName;
          savedBytes = bytes;
          return '/storage/$fileName';
        },
      );

      expect(result, SaveResult.saved);
      expect(savedName, 'signature-20261021-090807-006.png');
      expect(savedBytes, _transparentPng);
    });

    test('treats a dismissed save dialog as cancelled', () async {
      final result = await saveSignature(
        _transparentPng,
        saveFile: ({required fileName, required bytes}) =>
            throw PlatformException(code: 'CANCELLED'),
      );
      expect(result, SaveResult.cancelled);
    });

    test('reports platform errors as failures', () async {
      final result = await saveSignature(
        _transparentPng,
        saveFile: ({required fileName, required bytes}) =>
            throw PlatformException(code: 'security_exception'),
      );
      expect(result, SaveResult.failed);
    });

    test('reports unexpected errors as failures', () async {
      final result = await saveSignature(
        _transparentPng,
        saveFile: ({required fileName, required bytes}) =>
            throw const FileSystemException('disk full'),
      );
      expect(result, SaveResult.failed);
    });
  });

  test('saveResultMessage has a message for every result', () {
    expect(
      saveResultMessage(SaveResult.saved, _en),
      'Signature successfully saved!',
    );
    expect(saveResultMessage(SaveResult.cancelled, _en), 'Save cancelled');
    expect(
      saveResultMessage(SaveResult.failed, _en),
      'Failed to save signature',
    );
    expect(
      saveResultMessage(SaveResult.saved, const AppStrings('id')),
      'Tanda tangan berhasil disimpan!',
    );
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

    // Let fluttertoast's internal one-second timer finish.
    Future<void> settleToasts(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 2));

    Future<void> pumpResult(
      WidgetTester tester, {
      SaveSignatureFile saveFile = _noSave,
      ShareSignatureFile? shareFile,
      Future<File> Function(Uint8List bytes)? writeTempFile,
      Locale? locale,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ResultSignature(
            image: _transparentPng,
            whiteImage: _whitePng,
            showAd: false,
            saveFile: saveFile,
            shareFile: shareFile ?? (file, text) async {},
            writeTempFile:
                writeTempFile ?? (bytes) async => File('/unused/signature.png'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('does not save until the user taps Save', (tester) async {
      var saves = 0;
      await pumpResult(
        tester,
        saveFile: ({required fileName, required bytes}) async {
          saves++;
          return fileName;
        },
      );

      expect(saves, 0);
      expect(find.byType(Image), findsOneWidget);
      expect(toasts, isEmpty);
    });

    testWidgets('saves the transparent version by default', (tester) async {
      Uint8List? saved;
      await pumpResult(
        tester,
        saveFile: ({required fileName, required bytes}) async {
          saved = bytes;
          return fileName;
        },
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(saved, _transparentPng);
      expect(toasts, ['Signature successfully saved!']);
      await settleToasts(tester);
    });

    testWidgets('White option saves and previews the white version', (
      tester,
    ) async {
      Uint8List? saved;
      await pumpResult(
        tester,
        saveFile: ({required fileName, required bytes}) async {
          saved = bytes;
          return fileName;
        },
      );

      await tester.tap(find.text('White'));
      await tester.pump();

      final preview = tester.widget<Image>(find.byType(Image));
      expect((preview.image as MemoryImage).bytes, _whitePng);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'White'))
            .selected,
        isTrue,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(saved, _whitePng);
      await settleToasts(tester);
    });

    testWidgets('preview area is white for both background options', (
      tester,
    ) async {
      await pumpResult(tester);
      Color? previewColor() {
        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(Image),
                matching: find.byType(Container),
              )
              .first,
        );
        return (box.decoration as BoxDecoration?)?.color;
      }

      expect(previewColor(), Colors.white);
      await tester.tap(find.text('White'));
      await tester.pump();
      expect(previewColor(), Colors.white);
    });

    testWidgets('a cancelled save can be retried', (tester) async {
      var attempts = 0;
      await pumpResult(
        tester,
        saveFile: ({required fileName, required bytes}) async {
          attempts++;
          if (attempts == 1) throw PlatformException(code: 'CANCELLED');
          return fileName;
        },
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(toasts, ['Save cancelled']);

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(toasts.last, 'Signature successfully saved!');
      await settleToasts(tester);
    });

    testWidgets('share sends the selected version with a message', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('result_test'),
      ))!;
      addTearDown(() => dir.deleteSync(recursive: true));
      File? shared;
      String? sharedText;

      await pumpResult(
        tester,
        writeTempFile: (bytes) async {
          final file = File('${dir.path}/shared.png');
          file.writeAsBytesSync(bytes);
          return file;
        },
        shareFile: (file, text) async {
          shared = file;
          sharedText = text;
        },
      );

      await tester.tap(find.text('White'));
      await tester.pump();
      await tester.tap(find.text('Share Signature'));
      await tester.pump();
      await tester.pump();

      expect(shared!.readAsBytesSync(), _whitePng);
      expect(sharedText, 'Here is my signature!');
    });

    testWidgets('share failures show a message instead of crashing', (
      tester,
    ) async {
      await pumpResult(
        tester,
        writeTempFile: (bytes) async =>
            throw const FileSystemException('no space'),
      );

      await tester.tap(find.text('Share Signature'));
      await tester.pump();
      await tester.pump();

      expect(toasts.last, 'Unable to share your signature');
      await settleToasts(tester);
    });

    testWidgets('leaving before the save finishes does not throw', (
      tester,
    ) async {
      await pumpResult(
        tester,
        saveFile: ({required fileName, required bytes}) =>
            Future.delayed(const Duration(seconds: 1), () => fileName),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Replace the page while the save is still pending.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(toasts, isEmpty);
    });

    testWidgets('is shown in Indonesian on Indonesian devices', (tester) async {
      await pumpResult(tester, locale: const Locale('id'));

      expect(find.text('Hasil'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);
      expect(find.text('Transparan'), findsOneWidget);
      expect(find.text('Putih'), findsOneWidget);
    });
  });
}
