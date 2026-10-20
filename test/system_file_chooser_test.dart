import 'package:dartlab/services/system_file_chooser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const channel = MethodChannel('dartlab/import');

void answerWith(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SystemFileChooser.pick', () {
    test('returns the name and the bytes of the picked file', () async {
      MethodCall? received;
      answerWith((call) async {
        received = call;
        return {
          'name': 'main.dart.txt',
          'bytes': Uint8List.fromList([1, 2, 3])
        };
      });

      final picked = await SystemFileChooser().pick();

      expect(received!.method, 'pickFile');
      expect(picked!.name, 'main.dart.txt');
      expect(picked.bytes, [1, 2, 3]);
    });

    test('closing the list gives null', () async {
      answerWith((call) async => null);

      expect(await SystemFileChooser().pick(), isNull);
    });

    test('a failure on the phone gives null', () async {
      answerWith((call) async => throw PlatformException(code: 'read_failed'));

      expect(await SystemFileChooser().pick(), isNull);
    });

    test('an answer without a name or bytes gives null', () async {
      answerWith((call) async => {'name': 'a.dart'});

      expect(await SystemFileChooser().pick(), isNull);
    });

    test('with no native side at all (not Android) it gives null', () async {
      expect(await SystemFileChooser().pick(), isNull);
    });
  });
}
