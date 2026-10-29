import 'package:dartlab/utils/fold_regions.dart';
import 'package:dartlab/widgets/code_editor/line_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const style = TextStyle(fontSize: 14);
const strut = StrutStyle(fontSize: 14, height: 1.0, forceStrutHeight: true);

LineLayout layoutOf(
  String text, {
  double width = 500,
  bool wrap = true,
  List<LineRange> hidden = const [],
}) {
  return LineLayout()
    ..ensure(
      text: text,
      wrapWidth: width,
      style: style,
      fontSize: 14,
      lineHeight: 20,
      strut: strut,
      wordWrap: wrap,
      hiddenLines: hidden,
      hiddenSig: hidden.map((r) => '${r.first}-${r.last}').join(','),
    );
}

void main() {
  group('LineLayout', () {
    test('every short line is one row tall', () {
      expect(layoutOf('a\nb\nc').lineTops, [0, 20, 40, 60]);
    });

    test('an empty text is one empty line', () {
      expect(layoutOf('').lineTops, [0, 20]);
    });

    test('a line that wraps takes more rows', () {
      final layout = layoutOf('aaaaaaaaaa\nb', width: 70);

      expect(layout.lineTops.length, 3);
      expect(layout.lineTops[1], greaterThan(20));
    });

    test('a folded block takes one placeholder row', () {
      final layout = layoutOf('a\nb\nc\nd', hidden: [LineRange(1, 2)]);

      expect(layout.lineTops, [0, 20, 40, 40, 60]);
    });

    test('with word wrap off, the widest line is measured', () {
      final layout = layoutOf('ab\nabcd\nabc', wrap: false);

      expect(layout.maxLineWidth, closeTo(layout.measurer.measureLineWidth('abcd'), 0.01));
      expect(layout.lineTops, [0, 20, 40, 60]);
    });

    test('with word wrap on, no width is measured', () {
      expect(layoutOf('abcd', wrap: true).maxLineWidth, 0);
    });

    test('the lines are kept for the fold chips', () {
      expect(layoutOf('x\ny').lines, ['x', 'y']);
    });

    test('a changed text is laid out again, an unchanged one is not touched', () {
      final layout = layoutOf('a\nb');
      final tops = layout.lineTops;

      layout.ensure(
        text: 'a\nb',
        wrapWidth: 500,
        style: style,
        fontSize: 14,
        lineHeight: 20,
        strut: strut,
        wordWrap: true,
        hiddenLines: const [],
        hiddenSig: '',
      );
      expect(identical(layout.lineTops, tops), isTrue);

      layout.ensure(
        text: 'a\nb\nc',
        wrapWidth: 500,
        style: style,
        fontSize: 14,
        lineHeight: 20,
        strut: strut,
        wordWrap: true,
        hiddenLines: const [],
        hiddenSig: '',
      );
      expect(layout.lineTops.length, 4);
    });
  });

  group('LineLayout.isLineHidden', () {
    final ranges = [LineRange(2, 4), LineRange(8, 8)];

    test('is true inside a hidden range', () {
      expect(LineLayout.isLineHidden(2, ranges), isTrue);
      expect(LineLayout.isLineHidden(4, ranges), isTrue);
      expect(LineLayout.isLineHidden(8, ranges), isTrue);
    });

    test('is false outside', () {
      expect(LineLayout.isLineHidden(1, ranges), isFalse);
      expect(LineLayout.isLineHidden(5, ranges), isFalse);
      expect(LineLayout.isLineHidden(9, ranges), isFalse);
    });
  });
}
