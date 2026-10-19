import 'package:dartlab/widgets/console/console_height.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consoleMaxHeight', () {
    test('without a keyboard: 70% of the screen', () {
      expect(consoleMaxHeight(screenHeight: 1000, keyboardHeight: 0), 700);
    });

    test('with the keyboard up: 35% of what is left', () {
      expect(
        consoleMaxHeight(screenHeight: 1000, keyboardHeight: 400),
        closeTo(210, 0.001),
      );
    });

    test('a keyboard taller than the screen leaves nothing', () {
      expect(consoleMaxHeight(screenHeight: 500, keyboardHeight: 800), 0);
    });
  });

  group('consoleHeightFor', () {
    double heightFor(double wanted, {double min = 120, double max = 700}) =>
        consoleHeightFor(wanted: wanted, minOpen: min, maxHeight: max);

    test('keeps the height the user chose', () => expect(heightFor(300), 300));

    test('never below what the console\'s own parts need', () {
      expect(heightFor(50), kConsoleMinUsableHeight);
      expect(heightFor(130), kConsoleMinUsableHeight);
    });

    test('a larger configured minimum is respected', () {
      expect(heightFor(50, min: 200), 200);
    });

    test('never above the maximum', () => expect(heightFor(900), 700));

    test('a maximum below the least that fits is ignored', () {
      expect(heightFor(300, max: 100), kConsoleMinUsableHeight);
      expect(heightFor(300, min: 220, max: 100), 220);
    });
  });
}
