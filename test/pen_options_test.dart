import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/pen_options.dart';

void main() {
  group('penColorOptions', () {
    test('offers six colors starting with black as the default', () {
      expect(penColorOptions, hasLength(6));
      expect(penColorOptions.first.color, Colors.black);
    });

    test('has unique names and colors', () {
      final names = penColorOptions.map((o) => o.name).toSet();
      final colors = penColorOptions.map((o) => o.color).toSet();
      expect(names, hasLength(penColorOptions.length));
      expect(colors, hasLength(penColorOptions.length));
    });

    test('names are spelled correctly', () {
      expect(penColorOptions.map((o) => o.name), [
        'Black',
        'Red',
        'Green',
        'Blue',
        'Yellow',
        'Brown',
      ]);
    });
  });

  group('strokeCapOptions', () {
    test('covers every StrokeCap value exactly once', () {
      expect(
        strokeCapOptions.map((o) => o.strokeCap).toSet(),
        StrokeCap.values.toSet(),
      );
      expect(strokeCapOptions, hasLength(StrokeCap.values.length));
    });
  });

  group('stroke width limits', () {
    test('default lies within min and max', () {
      expect(minStrokeWidth, lessThan(maxStrokeWidth));
      expect(
        defaultStrokeWidth,
        inInclusiveRange(minStrokeWidth, maxStrokeWidth),
      );
    });

    test('slider divisions give one step per pixel', () {
      expect((maxStrokeWidth - minStrokeWidth) / strokeWidthDivisions, 1);
    });
  });

  group('buildPenPaint', () {
    test('applies color, stroke cap and width', () {
      final paint = buildPenPaint(
        color: Colors.red,
        strokeCap: StrokeCap.square,
        strokeWidth: 7,
      );

      expect(paint.color.toARGB32(), Colors.red.toARGB32());
      expect(paint.strokeCap, StrokeCap.square);
      expect(paint.strokeWidth, 7);
    });

    test('clamps width below the minimum', () {
      final paint = buildPenPaint(
        color: Colors.black,
        strokeCap: StrokeCap.round,
        strokeWidth: 0,
      );
      expect(paint.strokeWidth, minStrokeWidth);
    });

    test('clamps width above the maximum', () {
      final paint = buildPenPaint(
        color: Colors.black,
        strokeCap: StrokeCap.round,
        strokeWidth: 100,
      );
      expect(paint.strokeWidth, maxStrokeWidth);
    });
  });
}
