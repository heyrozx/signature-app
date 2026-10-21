import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// A single continuous line drawn with one pen setting.
class SignatureStroke {
  final List<Offset> points;
  final Color color;
  final StrokeCap strokeCap;
  final double strokeWidth;

  SignatureStroke({
    required this.color,
    required this.strokeCap,
    required this.strokeWidth,
    List<Offset>? points,
  }) : points = points ?? [];

  Paint toPaint() => Paint()
    ..color = color
    ..strokeCap = strokeCap
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
}

/// Holds the strokes of a signature and the pen used for new strokes.
///
/// Changing the pen only affects strokes drawn afterwards, so existing
/// strokes are never lost.
class SignatureController extends ChangeNotifier {
  SignatureController({
    this.color = Colors.black,
    this.strokeCap = StrokeCap.round,
    this.strokeWidth = 5,
  });

  Color color;
  StrokeCap strokeCap;
  double strokeWidth;

  final List<SignatureStroke> _strokes = [];

  List<SignatureStroke> get strokes => List.unmodifiable(_strokes);

  bool get isEmpty => _strokes.every((stroke) => stroke.points.isEmpty);

  bool get isNotEmpty => !isEmpty;

  void startStroke(Offset point) {
    _strokes.add(
      SignatureStroke(
        color: color,
        strokeCap: strokeCap,
        strokeWidth: strokeWidth,
        points: [point],
      ),
    );
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (_strokes.isEmpty) {
      startStroke(point);
      return;
    }
    _strokes.last.points.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  /// Renders the signature on a transparent background as PNG bytes.
  ///
  /// Returns null when there is nothing to export or [size] is empty.
  Future<Uint8List?> toPngBytes(Size size) async {
    if (isEmpty || size.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    paintStrokes(Canvas(recorder), _strokes);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

void paintStrokes(Canvas canvas, List<SignatureStroke> strokes) {
  for (final stroke in strokes) {
    final paint = stroke.toPaint();
    final points = stroke.points;
    if (points.length == 1) {
      // A tap draws a dot.
      canvas.drawPoints(ui.PointMode.points, points, paint);
      continue;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

/// Drawing surface bound to a [SignatureController].
class SignaturePad extends StatefulWidget {
  final SignatureController controller;
  final Color backgroundColor;

  const SignaturePad({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.transparent,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  Size _size = Size.zero;

  /// Exports the signature at the size it is currently drawn on screen.
  Future<Uint8List?> exportPng() => widget.controller.toPngBytes(_size);

  bool _contains(Offset point) =>
      point.dx >= 0 &&
      point.dy >= 0 &&
      point.dx <= _size.width &&
      point.dy <= _size.height;

  // Leaving the pad lifts the pen, so re-entering starts a new stroke instead
  // of drawing a line across the edge.
  bool _strokeActive = false;

  void _handlePoint(Offset point) {
    if (!_contains(point)) {
      _strokeActive = false;
    } else if (_strokeActive) {
      widget.controller.extendStroke(point);
    } else {
      widget.controller.startStroke(point);
      _strokeActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _handlePoint(details.localPosition),
          onPanUpdate: (details) => _handlePoint(details.localPosition),
          onPanEnd: (_) => _strokeActive = false,
          onPanCancel: () => _strokeActive = false,
          child: ColoredBox(
            color: widget.backgroundColor,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SignaturePainter(widget.controller),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final SignatureController controller;

  _SignaturePainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintStrokes(canvas, controller.strokes);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      oldDelegate.controller != controller;
}
