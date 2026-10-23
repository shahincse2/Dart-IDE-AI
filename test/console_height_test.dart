import 'package:dartlab/widgets/console/console_height.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consoleMaxHeight', () {
    test('without information about the room: 70% of the screen', () {
      expect(consoleMaxHeight(screenHeight: 1000), 700);
    });

    test('a smaller room (keyboard up) limits it', () {
      expect(consoleMaxHeight(screenHeight: 1000, roomHeight: 148.6), 148.6);
    });

    test('a larger room does not raise it above 70% of the screen', () {
      expect(consoleMaxHeight(screenHeight: 1000, roomHeight: 900), 700);
    });

    test('no room at all leaves the console nothing', () {
      expect(consoleMaxHeight(screenHeight: 1000, roomHeight: -20), 0);
    });
  });

  group('consoleHeightFor', () {
    double heightFor(
      double wanted, {
      double min = 120,
      double max = 700,
      bool input = false,
    }) =>
        consoleHeightFor(
          wanted: wanted,
          minOpen: min,
          maxHeight: max,
          withInputBar: input,
        );

    test('keeps the height the user chose', () => expect(heightFor(300), 300));

    test('never below the configured minimum', () => expect(heightFor(50), 120));

    test('while the input bar shows, never below what it needs', () {
      expect(heightFor(50, input: true), kConsoleInputBarMinHeight);
      expect(heightFor(50, min: 200, input: true), 200);
    });

    test('never above the maximum', () => expect(heightFor(900), 700));

    test('a maximum below the least that fits is ignored', () {
      expect(heightFor(300, max: 100), 120);
      expect(heightFor(300, max: 100, input: true), kConsoleInputBarMinHeight);
    });
  });
}
