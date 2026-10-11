import 'package:dartlab/services/runner/stdin_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StdinBridge', () {
    test('requestLine tells the listeners and marks a pending wait', () async {
      final bridge = StdinBridge();
      var requests = 0;
      final subscription = bridge.requests.listen((_) => requests++);

      bridge.requestLine();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.hasPending, isTrue);
      expect(requests, 1);
      await subscription.cancel();
    });

    test('reply hands the line to the attached receiver and ends the wait', () {
      final bridge = StdinBridge();
      final received = <String>[];
      bridge.attach(received.add);

      bridge.requestLine();
      bridge.reply('hello');

      expect(received, ['hello']);
      expect(bridge.hasPending, isFalse);
    });

    test('a reply with nobody waiting is ignored', () {
      final bridge = StdinBridge();
      final received = <String>[];
      bridge.attach(received.add);

      bridge.reply('nobody asked');

      expect(received, isEmpty);
    });

    test('a second reply to the same request is ignored', () {
      final bridge = StdinBridge();
      final received = <String>[];
      bridge.attach(received.add);

      bridge.requestLine();
      bridge.reply('first');
      bridge.reply('second');

      expect(received, ['first']);
    });

    test('detach ends an open wait without delivering anything', () {
      final bridge = StdinBridge();
      final received = <String>[];
      bridge.attach(received.add);
      bridge.requestLine();

      bridge.detach();
      bridge.reply('too late');

      expect(bridge.hasPending, isFalse);
      expect(received, isEmpty);
    });

    test('waitingChanges reports the start and the end of a wait', () async {
      final bridge = StdinBridge();
      final seen = <bool>[];
      final subscription = bridge.waitingChanges.listen(seen.add);
      bridge.attach((_) {});

      bridge.requestLine();
      bridge.reply('a');
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true, false]);
      await subscription.cancel();
    });
  });
}
