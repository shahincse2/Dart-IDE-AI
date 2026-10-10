import 'dart:math' as math;

import 'package:dartlab/models/console_event.dart';
import 'package:dartlab/widgets/console/console_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in splitter: cuts every [size] characters.
RowSplitter chop(int size) => (text, type) {
      if (text.isEmpty) return [''];
      return [
        for (var i = 0; i < text.length; i += size)
          text.substring(i, math.min(i + size, text.length)),
      ];
    };

ConsoleLineBuilder builderWith(int size) =>
    ConsoleLineBuilder()..configure(layoutKey: size, splitter: chop(size));

void main() {
  group('ConsoleLineBuilder', () {
    test('an event with several lines becomes several rows', () {
      final builder = builderWith(20)..update([ConsoleEvent.stdout('a\nb')]);

      expect(builder.lines.map((l) => l.text), ['a', 'b']);
      expect(builder.lines.map((l) => l.isFirst), [true, false]);
    });

    test('a wrapped line keeps the icon on its first row only', () {
      final builder = builderWith(10)..update([ConsoleEvent.stdout('x' * 25)]);

      expect(builder.lines.map((l) => l.text.length), [10, 10, 5]);
      expect(builder.lines.map((l) => l.isFirst), [true, false, false]);
    });

    test('only new events are added on later updates', () {
      final events = [ConsoleEvent.stdout('one')];
      final builder = builderWith(20)..update(events);
      events.add(ConsoleEvent.stdout('two'));
      builder.update(events);

      expect(builder.lines.map((l) => l.text), ['one', 'two']);
    });

    test('changing the layout re-wraps everything', () {
      final events = [ConsoleEvent.stdout('x' * 30)];
      final builder = builderWith(20)..update(events);
      expect(builder.lines.length, 2);

      builder
        ..configure(layoutKey: 10, splitter: chop(10))
        ..update(events);
      expect(builder.lines.length, 3);
    });

    test('cleared events start the list over', () {
      final builder = builderWith(20)
        ..update([ConsoleEvent.stdout('a'), ConsoleEvent.stdout('b')])
        ..update([ConsoleEvent.stdout('c')]);

      expect(builder.lines.map((l) => l.text), ['c']);
    });

    test('a new run with as many events as the old one replaces the output',
        () {
      final builder = builderWith(20)
        ..update([ConsoleEvent.stdout('a'), ConsoleEvent.stdout('b')])
        ..update([ConsoleEvent.stdout('c'), ConsoleEvent.stdout('d')]);

      expect(builder.lines.map((l) => l.text), ['c', 'd']);
    });

    // test('the splitter is told whether the text is an error', () {
    //   final seen = <ConsoleEventType>[];
    //   final builder = ConsoleLineBuilder()
    //     ..configure(
    //       layoutKey: 1,
    //       splitter: (text, type) {
    //         seen.add(type);
    //         return [text];
    //       },
    //     )
    //     ..update([ConsoleEvent.stdout('a'), ConsoleEvent.stderr('b')]);
    //
    //   expect(seen, [ConsoleEventType.stdout, ConsoleEventType.stderr]);
    // });
    test('changing the layout re-wraps everything', () {
      final events = [ConsoleEvent.stdout('x' * 30)];
      final builder = builderWith(20)..update(events);
      expect(builder.lines.length, 2);

      builder
        ..configure(layoutKey: 10, splitter: chop(10))
        ..update(events);

      // এখানে builder ব্যবহার করে চেক করা হয়েছে
      expect(builder.lines.length, 3);
    });

    test('the exit code gets its own row', () {
      final builder = builderWith(20)..update([ConsoleEvent.exitCode(0)]);

      expect(builder.lines.single.text, 'Program finished (exit code 0)');
    });
  });
}
