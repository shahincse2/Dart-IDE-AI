import 'package:dartlab/models/console_event.dart';
import 'package:dartlab/widgets/console/console_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wrapRow', () {
    test('short text stays on one row', () {
      expect(wrapRow('hello', 10), ['hello']);
      expect(wrapRow('', 10), ['']);
    });

    test('long text without spaces is cut at the width', () {
      expect(wrapRow('a' * 12, 5), ['aaaaa', 'aaaaa', 'aa']);
    });

    test('prefers to break at a space', () {
      expect(wrapRow('hello brave new world', 12), ['hello brave', 'new world']);
    });

    test('non-ASCII text gets shorter rows', () {
      expect(wrapRow('α' * 10, 10), ['αααααα', 'αααα']);
    });

    test('never separates a character from its combining mark', () {
      const text = 'abcdee\u0301fgh';
      expect(wrapRow(text, 10), ['abcde', 'e\u0301fgh']);
    });
  });

  group('ConsoleLineBuilder', () {
    test('an event with several lines becomes several rows', () {
      final builder = ConsoleLineBuilder()
        ..update([ConsoleEvent.stdout('a\nb')], columns: 20);

      expect(builder.lines.map((l) => l.text), ['a', 'b']);
      expect(builder.lines.map((l) => l.isFirst), [true, false]);
    });

    test('only new events are added on later updates', () {
      final events = [ConsoleEvent.stdout('one')];
      final builder = ConsoleLineBuilder()..update(events, columns: 20);
      events.add(ConsoleEvent.stdout('two'));
      builder.update(events, columns: 20);

      expect(builder.lines.map((l) => l.text), ['one', 'two']);
    });

    test('changing the width re-wraps everything', () {
      final events = [ConsoleEvent.stdout('x' * 30)];
      final builder = ConsoleLineBuilder()..update(events, columns: 20);
      expect(builder.lines.length, 2);

      builder.update(events, columns: 10);
      expect(builder.lines.length, 3);
    });

    test('cleared events start the list over', () {
      final events = [ConsoleEvent.stdout('a'), ConsoleEvent.stdout('b')];
      final builder = ConsoleLineBuilder()..update(events, columns: 20);

      builder.update([ConsoleEvent.stdout('c')], columns: 20);
      expect(builder.lines.map((l) => l.text), ['c']);
    });

    test('the exit code gets its own row', () {
      final builder = ConsoleLineBuilder()
        ..update([ConsoleEvent.exitCode(0)], columns: 20);

      expect(builder.lines.single.text, 'Program finished (exit code 0)');
    });
  });
}
