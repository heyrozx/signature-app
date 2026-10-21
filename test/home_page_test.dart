import 'package:flutter/services.dart';
import 'package:flutter_signature_view/flutter_signature_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/main.dart';
import 'package:simple_signature/pen_options.dart';

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

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyHomePage()));
    await tester.pump();
  }

  Paint currentPen(WidgetTester tester) {
    return tester.widget<SignatureView>(find.byType(SignatureView)).penStyle!;
  }

  testWidgets('shows the canvas and every tool button', (tester) async {
    await pumpHome(tester);

    expect(find.text('Signature'), findsOneWidget);
    expect(find.byType(SignatureView), findsOneWidget);
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
  });

  testWidgets('starts with a black round pen at the default width', (
    tester,
  ) async {
    await pumpHome(tester);

    final pen = currentPen(tester);
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

    expect(toastCalls, hasLength(1));
    expect(toastCalls.single.method, 'showToast');
    expect(
      (toastCalls.single.arguments as Map)['msg'],
      'Your signature is empty',
    );
    expect(find.byType(MyHomePage), findsOneWidget);
    expect(find.text('Result'), findsNothing);

    // Let fluttertoast's internal one-second timer finish.
    await tester.pump(const Duration(seconds: 2));
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
    expect(currentPen(tester).color.toARGB32(), Colors.blue.toARGB32());
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
    expect(currentPen(tester).strokeCap, StrokeCap.square);
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

    expect(currentPen(tester).strokeWidth, maxStrokeWidth);
  });

  testWidgets('drawing then clearing empties the signature', (tester) async {
    await pumpHome(tester);

    final canvas = find.byType(SignatureView);
    await tester.drag(canvas, const Offset(120, 40));
    await tester.pump();

    final view = tester.widget<SignatureView>(canvas);
    expect(view.isEmpty, isFalse);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(view.isEmpty, isTrue);
  });
}
