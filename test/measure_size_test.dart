import 'package:dartlab/widgets/measure_size.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget boxOfHeight(double height, List<Size> seen) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: MeasureSize(
        onChange: seen.add,
        child: SizedBox(width: 100, height: height),
      ),
    ),
  );
}

void main() {
  group('MeasureSize', () {
    testWidgets('reports the size of its child', (tester) async {
      final seen = <Size>[];

      await tester.pumpWidget(boxOfHeight(50, seen));

      expect(seen, [const Size(100, 50)]);
    });

    testWidgets('reports again when the size changes', (tester) async {
      final seen = <Size>[];
      await tester.pumpWidget(boxOfHeight(50, seen));

      await tester.pumpWidget(boxOfHeight(80, seen));

      expect(seen, [const Size(100, 50), const Size(100, 80)]);
    });

    testWidgets('says nothing when the size stays the same', (tester) async {
      final seen = <Size>[];
      await tester.pumpWidget(boxOfHeight(50, seen));

      await tester.pumpWidget(boxOfHeight(50, seen));
      await tester.pump();

      expect(seen.length, 1);
    });
  });
}
