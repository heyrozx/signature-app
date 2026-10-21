import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/signature_pad.dart';

void main() {
  group('SignatureController', () {
    test('starts empty', () {
      final controller = SignatureController();
      expect(controller.isEmpty, isTrue);
      expect(controller.strokes, isEmpty);
    });

    test('records strokes with the pen active when they start', () {
      final controller = SignatureController(
        color: Colors.red,
        strokeCap: StrokeCap.square,
        strokeWidth: 8,
      );

      controller
        ..startStroke(const Offset(1, 1))
        ..extendStroke(const Offset(2, 2))
        ..extendStroke(const Offset(3, 3));

      expect(controller.isNotEmpty, isTrue);
      final stroke = controller.strokes.single;
      expect(stroke.points, const [Offset(1, 1), Offset(2, 2), Offset(3, 3)]);
      expect(stroke.color, Colors.red);
      expect(stroke.strokeCap, StrokeCap.square);
      expect(stroke.strokeWidth, 8);
    });

    test('changing the pen keeps existing strokes unchanged', () {
      final controller = SignatureController()
        ..startStroke(const Offset(1, 1))
        ..extendStroke(const Offset(5, 5));

      controller
        ..color = Colors.blue
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.butt;
      controller
        ..startStroke(const Offset(10, 10))
        ..extendStroke(const Offset(20, 20));

      expect(controller.strokes, hasLength(2));
      expect(controller.strokes[0].color, Colors.black);
      expect(controller.strokes[0].strokeWidth, 5);
      expect(controller.strokes[0].strokeCap, StrokeCap.round);
      expect(controller.strokes[1].color, Colors.blue);
      expect(controller.strokes[1].strokeWidth, 12);
      expect(controller.strokes[1].strokeCap, StrokeCap.butt);
    });

    test('extendStroke without a stroke starts a new one', () {
      final controller = SignatureController()
        ..extendStroke(const Offset(4, 4));
      expect(controller.strokes.single.points, const [Offset(4, 4)]);
    });

    test('clear removes every stroke and notifies listeners', () {
      final controller = SignatureController()..startStroke(const Offset(1, 1));
      var notified = 0;
      controller.addListener(() => notified++);

      controller.clear();

      expect(controller.isEmpty, isTrue);
      expect(notified, 1);
    });

    test('clear on an empty signature does not notify', () {
      final controller = SignatureController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.clear();

      expect(notified, 0);
    });

    test('strokes list cannot be modified from outside', () {
      final controller = SignatureController()..startStroke(const Offset(1, 1));
      expect(() => controller.strokes.clear(), throwsUnsupportedError);
    });

    test('toPngBytes returns null when empty or size is zero', () async {
      final empty = SignatureController();
      expect(await empty.toPngBytes(const Size(100, 100)), isNull);

      final drawn = SignatureController()..startStroke(const Offset(1, 1));
      expect(await drawn.toPngBytes(Size.zero), isNull);
    });
  });

  testWidgets('toPngBytes renders a PNG of the requested size', (tester) async {
    final controller = SignatureController(strokeWidth: 4)
      ..startStroke(const Offset(10, 10))
      ..extendStroke(const Offset(90, 40));

    final bytes = (await tester.runAsync(
      () => controller.toPngBytes(const Size(120, 60)),
    ))!;

    // PNG signature.
    expect(bytes.sublist(0, 8), [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    final image = (await tester.runAsync(() => _decode(bytes)))!;
    expect(image.width, 120);
    expect(image.height, 60);
    image.dispose();
  });

  group('SignaturePad', () {
    Future<SignatureController> pumpPad(WidgetTester tester) async {
      final controller = SignatureController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: SignaturePad(controller: controller),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('dragging draws a stroke', (tester) async {
      final controller = await pumpPad(tester);

      await tester.drag(find.byType(SignaturePad), const Offset(100, 50));
      await tester.pump();

      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.points.length, greaterThan(1));
    });

    testWidgets('each drag gesture becomes its own stroke', (tester) async {
      final controller = await pumpPad(tester);
      final pad = find.byType(SignaturePad);

      await tester.drag(pad, const Offset(60, 0));
      await tester.drag(pad, const Offset(0, 60));
      await tester.pump();

      expect(controller.strokes, hasLength(2));
    });

    testWidgets('leaving the pad lifts the pen', (tester) async {
      final controller = await pumpPad(tester);
      final center = tester.getCenter(find.byType(SignaturePad));

      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(0, 500)); // outside the pad
      await gesture.moveBy(const Offset(0, -500)); // back inside
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.up();
      await tester.pump();

      // The excursion outside splits the line into two strokes, and no
      // recorded point lies outside the pad.
      expect(controller.strokes, hasLength(2));
      final bounds = Offset.zero & tester.getSize(find.byType(SignaturePad));
      final allPoints = controller.strokes.expand((s) => s.points);
      expect(allPoints.every(bounds.inflate(0.01).contains), isTrue);
    });

    testWidgets('exportPng uses the on-screen size', (tester) async {
      final controller = await pumpPad(tester);
      await tester.drag(find.byType(SignaturePad), const Offset(100, 50));
      await tester.pump();

      final state = tester.state<SignaturePadState>(find.byType(SignaturePad));
      final bytes = (await tester.runAsync(state.exportPng))!;
      final image = (await tester.runAsync(() => _decode(bytes)))!;

      expect(controller.isNotEmpty, isTrue);
      expect(image.width, 300);
      expect(image.height, 200);
      image.dispose();
    });
  });
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
