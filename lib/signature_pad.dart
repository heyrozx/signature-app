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
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  /// Area covered by the stroke, including its thickness.
  Rect? get bounds {
    if (points.isEmpty) return null;
    var rect = Rect.fromPoints(points.first, points.first);
    for (final point in points.skip(1)) {
      rect = rect.expandToInclude(Rect.fromPoints(point, point));
    }
    return rect.inflate(strokeWidth / 2);
  }
}

/// Holds the strokes of a signature and the pen used for new strokes.
///
/// Changing the pen only affects strokes drawn afterwards, so existing
/// strokes are never lost. Starting a stroke and clearing can be undone.
class SignatureController extends ChangeNotifier {
  SignatureController({
    this.color = Colors.black,
    this.strokeCap = StrokeCap.round,
    this.strokeWidth = 5,
  });

  /// Points closer than this to the previous one are dropped; they add no
  /// detail and make curves jittery.
  static const double minPointDistance = 0.5;

  Color color;
  StrokeCap strokeCap;
  double strokeWidth;

  List<SignatureStroke> _strokes = [];
  final List<List<SignatureStroke>> _undoStack = [];
  final List<List<SignatureStroke>> _redoStack = [];

  List<SignatureStroke> get strokes => List.unmodifiable(_strokes);

  bool get isEmpty => _strokes.every((stroke) => stroke.points.isEmpty);

  bool get isNotEmpty => !isEmpty;

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  void _recordHistory() {
    _undoStack.add(List.of(_strokes));
    _redoStack.clear();
  }

  void startStroke(Offset point) {
    _recordHistory();
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
    final points = _strokes.last.points;
    if ((points.last - point).distance < minPointDistance) return;
    points.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _recordHistory();
    _strokes = [];
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(_strokes);
    _strokes = _undoStack.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(_strokes);
    _strokes = _redoStack.removeLast();
    notifyListeners();
  }

  /// Area covered by every stroke, or null when the signature is empty.
  Rect? get bounds {
    Rect? result;
    for (final stroke in _strokes) {
      final rect = stroke.bounds;
      if (rect == null) continue;
      result = result == null ? rect : result.expandToInclude(rect);
    }
    return result;
  }

  /// The part of a [canvasSize] canvas that [toPngBytes] exports: the strokes
  /// plus [padding] when [crop] is true, otherwise the whole canvas.
  Rect? exportArea(Size canvasSize, {bool crop = true, double padding = 16}) {
    final canvas = Offset.zero & canvasSize;
    if (!crop) return canvas;
    final strokes = bounds;
    if (strokes == null) return null;
    final area = strokes.inflate(padding).intersect(canvas);
    return area.isEmpty ? null : area;
  }

  /// Renders the signature as PNG bytes.
  ///
  /// The image is cropped to the strokes (see [exportArea]) and drawn on a
  /// transparent background unless [whiteBackground] is set. [pixelRatio]
  /// scales the output so it stays sharp on high density screens.
  /// Returns null when there is nothing to export.
  Future<Uint8List?> toPngBytes(
    Size canvasSize, {
    bool whiteBackground = false,
    bool crop = true,
    double padding = 16,
    double pixelRatio = 1,
  }) async {
    if (isEmpty || canvasSize.isEmpty) return null;
    final area = exportArea(canvasSize, crop: crop, padding: padding);
    if (area == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-area.left, -area.top);
    if (whiteBackground) {
      canvas.drawRect(area, Paint()..color = Colors.white);
    }
    paintStrokes(canvas, _strokes);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (area.width * pixelRatio).ceil(),
      (area.height * pixelRatio).ceil(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

/// Builds a smooth path through [points] using quadratic curves between the
/// midpoints of consecutive points.
Path smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) {
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
  for (var i = 1; i < points.length - 1; i++) {
    final control = points[i];
    final end = Offset.lerp(points[i], points[i + 1], 0.5)!;
    path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

void paintStrokes(Canvas canvas, List<SignatureStroke> strokes) {
  for (final stroke in strokes) {
    final paint = stroke.toPaint();
    final points = stroke.points;
    if (points.isEmpty) continue;
    if (points.length == 1) {
      // A tap draws a dot.
      canvas.drawPoints(ui.PointMode.points, points, paint);
      continue;
    }
    canvas.drawPath(smoothPath(points), paint);
  }
}

/// Drawing surface bound to a [SignatureController].
///
/// Shows a baseline and an optional [hint] to guide the user. Neither is
/// part of the exported image.
class SignaturePad extends StatefulWidget {
  final SignatureController controller;
  final Color backgroundColor;
  final bool showGuide;
  final String? hint;

  const SignaturePad({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.transparent,
    this.showGuide = true,
    this.hint,
  });

  /// Baseline position as a fraction of the pad height.
  static const double guideLineFraction = 0.7;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  Size _size = Size.zero;

  /// Exports the signature drawn on screen, cropped to its strokes and
  /// rendered at the device pixel ratio.
  Future<Uint8List?> exportPng({bool whiteBackground = false}) {
    return widget.controller.toPngBytes(
      _size,
      whiteBackground: whiteBackground,
      pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
  }

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

  Widget _buildGuide(BoxConstraints constraints) {
    final lineTop = constraints.maxHeight * SignaturePad.guideLineFraction;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 24,
            right: 24,
            top: lineTop,
            child: Container(height: 1, color: Colors.grey.shade300),
          ),
          Positioned(
            left: 24,
            top: lineTop - 30,
            child: Text(
              '×',
              style: TextStyle(fontSize: 24, color: Colors.grey.shade400),
            ),
          ),
          if (widget.hint != null)
            Positioned(
              left: 24,
              right: 24,
              top: lineTop + 8,
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => AnimatedOpacity(
                  opacity: widget.controller.isEmpty ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.showGuide) _buildGuide(constraints),
                CustomPaint(
                  size: Size.infinite,
                  painter: _SignaturePainter(widget.controller),
                ),
              ],
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
