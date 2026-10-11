import 'dart:io';
import 'dart:isolate';

import 'package:dartlab/services/runner/stdin_mailbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StdinMailbox', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('mailbox_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a delivered line is received', () {
      final ui = StdinMailbox(dir.path);
      final program = StdinMailbox(dir.path);

      ui.deliver('hello');

      expect(program.waitForLine(), 'hello');
    });

    test('lines arrive in order, including non-ASCII text', () {
      final ui = StdinMailbox(dir.path);
      final program = StdinMailbox(dir.path);

      ui.deliver('শাহিন');
      ui.deliver('two');

      expect(program.waitForLine(), 'শাহিন');
      expect(program.waitForLine(), 'two');
    });

    test('an empty line is a line', () {
      final ui = StdinMailbox(dir.path);
      final program = StdinMailbox(dir.path);

      ui.deliver('');

      expect(program.waitForLine(), '');
    });

    test('waitForLine blocks another isolate until a line is delivered',
        () async {
      final path = dir.path;
      final received = Isolate.run(() => StdinMailbox(path).waitForLine());

      await Future<void>.delayed(const Duration(milliseconds: 150));
      StdinMailbox(path).deliver('late');

      expect(await received.timeout(const Duration(seconds: 10)), 'late');
    });
  });
}
