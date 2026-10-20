import 'dart:convert';

import 'package:dartlab/services/downloads_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const channel = MethodChannel('dartlab/downloads');

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

  group('DownloadsSaver.save', () {
    test('sends the name, content, type and folder, and returns where it went',
        () async {
      MethodCall? received;
      answerWith((call) async {
        received = call;
        return 'Download/DartLab/main.dart';
      });

      final where = await DownloadsSaver().save(
        fileName: 'main.dart',
        bytes: Uint8List.fromList(utf8.encode('// শুভ')),
      );

      expect(where, 'Download/DartLab/main.dart');
      expect(received!.method, 'saveToDownloads');
      final args = received!.arguments as Map;
      expect(args['fileName'], 'main.dart');
      expect(utf8.decode(args['bytes'] as Uint8List), '// শুভ');
      expect(args['mimeType'],
          'application/octet-stream'); // keeps main.dart as main.dart
      expect(args['subfolder'], 'DartLab');
    });

    test('a failure on the phone gives null', () async {
      answerWith((call) async => throw PlatformException(code: 'save_failed'));

      final where =
          await DownloadsSaver().save(fileName: 'a.dart', bytes: Uint8List(0));

      expect(where, isNull);
    });

    test('a phone too old for it says so, so the caller can use another way',
        () async {
      answerWith((call) async => throw PlatformException(code: 'unsupported'));

      expect(
        () => DownloadsSaver().save(fileName: 'a.dart', bytes: Uint8List(0)),
        throwsUnsupportedError,
      );
    });

    test('with no native side at all (not Android) it gives null', () async {
      final where =
          await DownloadsSaver().save(fileName: 'a.dart', bytes: Uint8List(0));

      expect(where, isNull);
    });
  });
}
