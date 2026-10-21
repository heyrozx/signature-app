import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/signature_pad.dart';

SignatureController _drawLine(
  Offset from,
  Offset to, {
  SignatureController? controller,
}) {
  return (controller ?? SignatureController())
    ..startStroke(from)
    ..extendStroke(to);
}

void main() {
  group('SignatureController', () {
    test('starts empty with nothing to undo or redo', () {
      final controller = SignatureController();
      expect(controller.isEmpty, isTrue);
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.bounds, isNull);
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

    test('drops points too close to the previous one', () {
      final controller = SignatureController()
        ..startStroke(const Offset(10, 10))
        ..extendStroke(const Offset(10.1, 10.1))
        ..extendStroke(const Offset(12, 10));

      expect(controller.strokes.single.points, const [
        Offset(10, 10),
        Offset(12, 10),
      ]);
    });

    test('changing the pen keeps existing strokes unchanged', () {
      final controller = _drawLine(const Offset(1, 1), const Offset(5, 5));

      controller
        ..color = Colors.blue
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.butt;
      _drawLine(
        const Offset(10, 10),
        const Offset(20, 20),
        controller: controller,
      );

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

    test('clear on an empty signature does nothing', () {
      final controller = SignatureController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.clear();

      expect(notified, 0);
      expect(controller.canUndo, isFalse);
    });

    test('strokes list cannot be modified from outside', () {
      final controller = SignatureController()..startStroke(const Offset(1, 1));
      expect(() => controller.strokes.clear(), throwsUnsupportedError);
    });
  });

  group('undo / redo', () {
    test('undo removes the last stroke and redo brings it back', () {
      final controller = _drawLine(const Offset(0, 0), const Offset(10, 0));
      _drawLine(
        const Offset(0, 10),
        const Offset(10, 10),
        controller: controller,
      );

      controller.undo();
      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.points.first, Offset.zero);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.strokes, hasLength(2));
      expect(controller.strokes.last.points.first, const Offset(0, 10));
      expect(controller.canRedo, isFalse);
    });

    test('undo can step back to an empty canvas', () {
      final controller = _drawLine(const Offset(0, 0), const Offset(10, 0));

      controller.undo();

      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
    });

    test('clear can be undone', () {
      final controller = _drawLine(const Offset(0, 0), const Offset(10, 0));
      _drawLine(
        const Offset(0, 10),
        const Offset(10, 10),
        controller: controller,
      );

      controller.clear();
      expect(controller.isEmpty, isTrue);

      controller.undo();
      expect(controller.strokes, hasLength(2));
    });

    test('drawing after undo discards the redo history', () {
      final controller = _drawLine(const Offset(0, 0), const Offset(10, 0));
      controller.undo();
      expect(controller.canRedo, isTrue);

      _drawLine(const Offset(5, 5), const Offset(6, 6), controller: controller);

      expect(controller.canRedo, isFalse);
      controller.redo(); // no-op
      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.points.first, const Offset(5, 5));
    });

    test('undo and redo with no history are no-ops', () {
      final controller = SignatureController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller
        ..undo()
        ..redo();

      expect(notified, 0);
    });

    test('undo keeps the strokes that came before intact', () {
      final controller = _drawLine(const Offset(0, 0), const Offset(10, 0))
        ..extendStroke(const Offset(20, 0));
      _drawLine(
        const Offset(0, 10),
        const Offset(10, 10),
        controller: controller,
      );

      controller.undo();

      expect(controller.strokes.single.points, const [
        Offset(0, 0),
        Offset(10, 0),
        Offset(20, 0),
      ]);
    });
  });

  group('bounds and export area', () {
    test('bounds cover every point plus half the stroke width', () {
      final controller = SignatureController(strokeWidth: 4);
      _drawLine(
        const Offset(10, 20),
        const Offset(50, 30),
        controller: controller,
      );

      expect(controller.bounds, const Rect.fromLTRB(8, 18, 52, 32));
    });

    test('export area adds padding and stays inside the canvas', () {
      final controller = SignatureController(strokeWidth: 2);
      _drawLine(
        const Offset(5, 50),
        const Offset(100, 60),
        controller: controller,
      );

      final area = controller.exportArea(const Size(300, 200), padding: 10)!;

      // Left edge would be -6, so it is clamped to the canvas.
      expect(area, const Rect.fromLTRB(0, 39, 111, 71));
    });

    test('without cropping the export area is the whole canvas', () {
      final controller = _drawLine(const Offset(5, 5), const Offset(6, 6));
      expect(
        controller.exportArea(const Size(300, 200), crop: false),
        const Rect.fromLTWH(0, 0, 300, 200),
      );
    });
  });

  group('toPngBytes', () {
    test('returns null when empty or size is zero', () async {
      final empty = SignatureController();
      expect(await empty.toPngBytes(const Size(100, 100)), isNull);

      final drawn = SignatureController()..startStroke(const Offset(1, 1));
      expect(await drawn.toPngBytes(Size.zero), isNull);
    });

    testWidgets('crops to the strokes', (tester) async {
      final controller = SignatureController(strokeWidth: 4);
      _drawLine(
        const Offset(100, 100),
        const Offset(200, 120),
        controller: controller,
      );

      final image = await _render(
        tester,
        () => controller.toPngBytes(const Size(400, 300), padding: 10),
      );

      // Strokes span 98..202 x 98..122, plus 10 px padding.
      expect(image.width, 124);
      expect(image.height, 44);
      image.dispose();
    });

    testWidgets('scales by the pixel ratio', (tester) async {
      final controller = _drawLine(const Offset(10, 10), const Offset(90, 40));

      final image = await _render(
        tester,
        () => controller.toPngBytes(
          const Size(120, 60),
          crop: false,
          pixelRatio: 2,
        ),
      );

      expect(image.width, 240);
      expect(image.height, 120);
      image.dispose();
    });

    testWidgets('background is transparent by default', (tester) async {
      final controller = _drawLine(const Offset(40, 40), const Offset(80, 40));

      final image = await _render(
        tester,
        () => controller.toPngBytes(const Size(120, 80), crop: false),
      );

      expect(await _pixel(tester, image, 2, 2), const ui.Color(0x00000000));
      image.dispose();
    });

    testWidgets('white background fills the whole image', (tester) async {
      final controller = _drawLine(const Offset(40, 40), const Offset(80, 40));

      final image = await _render(
        tester,
        () => controller.toPngBytes(
          const Size(120, 80),
          crop: false,
          whiteBackground: true,
        ),
      );

      expect(await _pixel(tester, image, 2, 2), const ui.Color(0xFFFFFFFF));
      // The stroke itself is still black.
      expect(await _pixel(tester, image, 60, 40), const ui.Color(0xFF000000));
      image.dispose();
    });
  });

  group('smoothPath', () {
    test('passes through the first and last points', () {
      const points = [Offset(0, 0), Offset(10, 20), Offset(30, 0)];
      final metrics = smoothPath(points).computeMetrics().single;

      final start = metrics.getTangentForOffset(0)!.position;
      final end = metrics.getTangentForOffset(metrics.length)!.position;
      expect(start, const Offset(0, 0));
      expect((end - const Offset(30, 0)).distance, lessThan(0.01));
    });

    test('rounds corners instead of drawing straight segments', () {
      const points = [Offset(0, 0), Offset(10, 20), Offset(20, 0)];
      final metrics = smoothPath(points).computeMetrics().single;
      final straight =
          (points[1] - points[0]).distance + (points[2] - points[1]).distance;

      // A curve that cuts the corner is shorter than the polyline.
      expect(metrics.length, lessThan(straight));
    });

    test('two points make a straight line', () {
      final bounds = smoothPath(const [Offset(0, 0), Offset(10, 0)])
          .getBounds();
      expect(bounds, const Rect.fromLTRB(0, 0, 10, 0));
    });
  });

  group('SignaturePad', () {
    Future<SignatureController> pumpPad(
      WidgetTester tester, {
      String? hint,
      bool showGuide = true,
    }) async {
      final controller = SignatureController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: SignaturePad(
                  controller: controller,
                  hint: hint,
                  showGuide: showGuide,
                ),
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

    testWidgets('hint shows only while the pad is empty', (tester) async {
      final controller = await pumpPad(tester, hint: 'Sign above the line');
      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

      expect(find.text('Sign above the line'), findsOneWidget);
      expect(opacity(), 1);

      await tester.drag(find.byType(SignaturePad), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(opacity(), 0);

      controller.clear();
      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('guide can be turned off', (tester) async {
      await pumpPad(tester, hint: 'hint', showGuide: false);
      expect(find.text('×'), findsNothing);
      expect(find.text('hint'), findsNothing);
    });

    testWidgets('exportPng crops and uses the device pixel ratio', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await pumpPad(tester);
      await tester.drag(find.byType(SignaturePad), const Offset(100, 0));
      await tester.pump();

      final state = tester.state<SignaturePadState>(find.byType(SignaturePad));
      final image = await _render(tester, state.exportPng);
      final area = controller.exportArea(const Size(300, 200))!;

      expect(image.width, (area.width * 2).ceil());
      expect(image.height, (area.height * 2).ceil());
      // Cropped: much smaller than the full 600x400 canvas.
      expect(image.height, lessThan(100));
      image.dispose();
    });
  });
}

Future<ui.Image> _render(
  WidgetTester tester,
  Future<Uint8List?> Function() export,
) async {
  final image = await tester.runAsync(() async {
    final bytes = (await export())!;
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
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  });
  return image!;
}

Future<ui.Color> _pixel(
  WidgetTester tester,
  ui.Image image,
  int x,
  int y,
) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  final i = (y * image.width + x) * 4;
  final bytes = data!.buffer.asUint8List();
  return ui.Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}
