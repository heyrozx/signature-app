import 'package:material_ui/material_ui.dart';

class PenColorOption {
  final String name;
  final Color color;
  const PenColorOption(this.name, this.color);
}

class StrokeCapOption {
  final String name;
  final StrokeCap strokeCap;
  const StrokeCapOption(this.name, this.strokeCap);
}

const List<PenColorOption> penColorOptions = [
  PenColorOption('Black', Colors.black),
  PenColorOption('Red', Colors.red),
  PenColorOption('Green', Colors.green),
  PenColorOption('Blue', Colors.blue),
  PenColorOption('Yellow', Colors.yellow),
  PenColorOption('Brown', Colors.brown),
];

const List<StrokeCapOption> strokeCapOptions = [
  StrokeCapOption('Round', StrokeCap.round),
  StrokeCapOption('Butt', StrokeCap.butt),
  StrokeCapOption('Square', StrokeCap.square),
];

const double minStrokeWidth = 1;
const double maxStrokeWidth = 20;
const double defaultStrokeWidth = 5;

Paint buildPenPaint({
  required Color color,
  required StrokeCap strokeCap,
  required double strokeWidth,
}) {
  return Paint()
    ..color = color
    ..strokeCap = strokeCap
    ..strokeWidth = strokeWidth.clamp(minStrokeWidth, maxStrokeWidth);
}
