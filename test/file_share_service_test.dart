import 'dart:convert';
import 'dart:typed_data';

import 'package:dartlab/services/file_share_service.dart';
import 'package:dartlab/services/system_file_chooser.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chooser that "picks" a prepared file, as if Android's list was used.
class _FakeChooser extends SystemFileChooser {
  _FakeChooser(this.name, this.text);

  final String? name;
  final String text;

  @override
  bool get isAvailable => true;

  @override
  Future<({String name, Uint8List bytes})?> pick() async {
    final fileName = name;
    if (fileName == null) return null;
    return (name: fileName, bytes: Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  group('cleanImportedName', () {
    test('leaves a Dart file alone', () {
      expect(cleanImportedName('main.dart'), 'main.dart');
      expect(cleanImportedName('screenEditor.dart'), 'screenEditor.dart');
    });

    test('a ".dart.txt" file (older exports) becomes a ".dart" file', () {
      expect(cleanImportedName('main.dart.txt'), 'main.dart');
      expect(cleanImportedName('myFile.DART.TXT'), 'myFile.DART');
    });

    test('a plain text file becomes a Dart file', () {
      expect(cleanImportedName('notes.txt'), 'notes.dart');
    });

    test('other names are left to the project to finish', () {
      expect(cleanImportedName('script'), 'script');
    });
  });

  group('FileShareService.importDartFile', () {
    test('gives the text (Bengali intact) under a cleaned name', () async {
      final service = FileShareService(chooser: _FakeChooser('main.dart.txt', '// শুভ সকাল'));

      final imported = await service.importDartFile();

      expect(imported!.name, 'main.dart');
      expect(imported.content, '// শুভ সকাল');
    });

    test('closing the file list gives null', () async {
      final service = FileShareService(chooser: _FakeChooser(null, ''));

      expect(await service.importDartFile(), isNull);
    });
  });
}
