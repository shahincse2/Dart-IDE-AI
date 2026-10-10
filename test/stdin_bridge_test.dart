import 'package:dartlab/services/runner/stdin_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// True if [future] completes within a short time, false if it stays pending.
Future<bool> completesSoon(Future<String> future) async {
  final result = await Future.any<Object?>([
    future,
    Future<Object?>.delayed(const Duration(milliseconds: 50), () => null),
  ]);
  return result != null;
}

void main() {
  group('StdinBridge', () {
    test('a reply answers the waiting read', () async {
      final bridge = StdinBridge();
      final line = bridge.readLine();
      expect(bridge.hasPending, isTrue);

      bridge.reply('hi');

      expect(await line, 'hi');
      expect(bridge.hasPending, isFalse);
    });

    test('cancel leaves the waiting read unanswered', () async {
      final bridge = StdinBridge();
      final line = bridge.readLine();

      bridge.cancel();

      expect(await completesSoon(line), isFalse);
      expect(bridge.hasPending, isFalse);
    });

    test('reads after a cancel never complete either', () async {
      final bridge = StdinBridge()..cancel();

      expect(await completesSoon(bridge.readLine()), isFalse);
    });

    test('reset makes reading possible again', () async {
      final bridge = StdinBridge()..cancel();
      bridge.reset();

      final line = bridge.readLine();
      bridge.reply('again');

      expect(await line, 'again');
    });

    test('waitingChanges reports the start and the end of a wait', () async {
      final bridge = StdinBridge();
      final seen = <bool>[];
      final subscription = bridge.waitingChanges.listen(seen.add);

      final line = bridge.readLine();
      bridge.reply('a');
      await line;
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true, false]);
      await subscription.cancel();
    });

    test('a reply with nobody waiting is ignored', () {
      final bridge = StdinBridge();
      bridge.reply('nobody asked');
      expect(bridge.hasPending, isFalse);
    });
  });
}
