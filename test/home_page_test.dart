import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/ad_consent.dart';
import 'package:simple_signature/main.dart';
import 'package:simple_signature/pen_options.dart';
import 'package:simple_signature/signature_pad.dart';

import 'ad_consent_test.dart' show FakeAdsPlatform;

const _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

void main() {
  late List<MethodCall> toastCalls;

  setUp(() {
    toastCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_toastChannel, (call) async {
          toastCalls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_toastChannel, null);
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    AdConsentManager? consent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          adConsentManager:
              consent ?? AdConsentManager(platform: FakeAdsPlatform()),
        ),
      ),
    );
    await tester.pump();
  }

  SignatureController controller(WidgetTester tester) {
    return tester.widget<SignaturePad>(find.byType(SignaturePad)).controller;
  }

  Future<void> draw(WidgetTester tester) async {
    await tester.drag(find.byType(SignaturePad), const Offset(120, 40));
    await tester.pump();
  }

  List<String> toastMessages() => toastCalls
      .map((call) => (call.arguments as Map)['msg'] as String)
      .toList();

  // Let fluttertoast's internal one-second timer finish.
  Future<void> settleToasts(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  testWidgets('shows the canvas and every tool button', (tester) async {
    await pumpHome(tester);

    expect(find.text('Signature'), findsOneWidget);
    expect(find.byType(SignaturePad), findsOneWidget);
    for (final icon in [
      Icons.share,
      Icons.brush,
      Icons.save,
      Icons.draw,
      Icons.palette,
      Icons.clear,
    ]) {
      expect(find.byIcon(icon), findsOneWidget);
    }
    expect(find.byIcon(Icons.privacy_tip), findsNothing);
  });

  testWidgets('starts with a black round pen at the default width', (
    tester,
  ) async {
    await pumpHome(tester);

    final pen = controller(tester);
    expect(pen.color.toARGB32(), Colors.black.toARGB32());
    expect(pen.strokeCap, StrokeCap.round);
    expect(pen.strokeWidth, defaultStrokeWidth);
  });

  testWidgets('saving an empty signature shows a toast and stays on page', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(toastMessages(), ['Your signature is empty']);
    expect(find.text('Result'), findsNothing);
    await settleToasts(tester);
  });

  testWidgets('sharing an empty signature shows a toast instead of crashing', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(toastMessages(), ['Your signature is empty']);
    await settleToasts(tester);
  });

  testWidgets('color dialog lists every color and applies the choice', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.palette));
    await tester.pumpAndSettle();

    for (final option in penColorOptions) {
      expect(find.text(option.name), findsOneWidget);
    }

    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(controller(tester).color.toARGB32(), Colors.blue.toARGB32());
  });

  testWidgets('stroke cap dialog lists every cap and applies the choice', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.draw));
    await tester.pumpAndSettle();

    for (final option in strokeCapOptions) {
      expect(find.text(option.name), findsOneWidget);
    }

    await tester.tap(find.text('Square'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(controller(tester).strokeCap, StrokeCap.square);
  });

  testWidgets('brush dialog slider changes the stroke width', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, minStrokeWidth);
    expect(slider.max, maxStrokeWidth);
    expect(slider.value, defaultStrokeWidth);

    // Drag the thumb all the way to the right edge.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();

    expect(controller(tester).strokeWidth, maxStrokeWidth);
  });

  testWidgets('changing the pen keeps what was already drawn', (tester) async {
    await pumpHome(tester);
    await draw(tester);
    expect(controller(tester).strokes, hasLength(1));

    await tester.tap(find.byIcon(Icons.palette));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // dismiss the dialog
    await tester.pumpAndSettle();

    final strokes = controller(tester).strokes;
    expect(strokes, hasLength(1));
    expect(strokes.single.color.toARGB32(), Colors.black.toARGB32());

    await draw(tester);
    final updated = controller(tester).strokes;
    expect(updated, hasLength(2));
    expect(updated.last.color.toARGB32(), Colors.red.toARGB32());
    expect(updated.last.strokeWidth, maxStrokeWidth);
  });

  testWidgets('drawing then clearing empties the signature', (tester) async {
    await pumpHome(tester);
    await draw(tester);
    expect(controller(tester).isNotEmpty, isTrue);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller(tester).isEmpty, isTrue);
  });

  testWidgets('privacy button appears when consent options are required', (
    tester,
  ) async {
    final platform = FakeAdsPlatform(privacyRequired: true);
    final consent = AdConsentManager(platform: platform);
    await pumpHome(tester, consent: consent);
    expect(find.byIcon(Icons.privacy_tip), findsNothing);

    await tester.runAsync(consent.gatherConsent);
    await tester.pump();
    expect(find.byIcon(Icons.privacy_tip), findsOneWidget);

    await tester.tap(find.byIcon(Icons.privacy_tip));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(platform.privacyFormCalls, 1);
  });
}
