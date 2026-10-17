import 'package:dartlab/providers/folder_focus_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FolderFocus', () {
    test('no folder is focused at first', () {
      expect(FolderFocus().folderFor('p', 'main.dart'), isNull);
    });

    test('a tapped folder is focused while the same file stays open', () {
      final focus = FolderFocus()..focus('p', 'lib', 'main.dart');

      expect(focus.folderFor('p', 'main.dart'), 'lib');
    });

    test('once another file is open, the focus no longer counts', () {
      final focus = FolderFocus()..focus('p', 'lib', 'main.dart');

      expect(focus.folderFor('p', 'lib/a.dart'), isNull);
    });

    test('it belongs to one project', () {
      final focus = FolderFocus()..focus('p', 'lib', 'main.dart');

      expect(focus.folderFor('q', 'main.dart'), isNull);
    });

    test('the project root can be focused too', () {
      final focus = FolderFocus()..focus('p', '', null);

      expect(focus.folderFor('p', null), '');
    });

    test('focusing tells the listeners', () {
      final focus = FolderFocus();
      var heard = 0;
      focus.addListener(() => heard++);

      focus.focus('p', 'lib', null);

      expect(heard, 1);
    });
  });
}
