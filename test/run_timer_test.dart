import 'package:dartlab/services/runner/run_timer.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('RunTimer', () {
    test('fires after the limit', () async {
      var fired = 0;
      final timer = RunTimer()..start(const Duration(milliseconds: 30), () => fired++);

      await wait(100);

      expect(fired, 1);
      timer.cancel();
    });

    test('does not fire while paused, and starts afresh after resume', () async {
      var fired = 0;
      final timer = RunTimer()..start(const Duration(milliseconds: 40), () => fired++);

      timer.pause();
      await wait(120);
      expect(fired, 0);

      timer.resume();
      await wait(25);
      expect(fired, 0); // a full limit starts again, it does not continue

      await wait(100);
      expect(fired, 1);
    });

    test('a cancelled timer never fires, not even after resume', () async {
      var fired = 0;
      final timer = RunTimer()..start(const Duration(milliseconds: 30), () => fired++);

      timer.cancel();
      timer.resume();
      await wait(100);

      expect(fired, 0);
    });
  });
}
