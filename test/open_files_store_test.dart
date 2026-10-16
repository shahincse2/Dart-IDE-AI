import 'package:dartlab/services/open_files_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OpenFilesStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('remembers the tabs of a project, in order, and the active one',
        () async {
      final store = OpenFilesStore();

      await store.write(
        'loop',
        const OpenFiles(tabs: ['b.dart', 'src/a.dart', 'c.dart'], active: 'src/a.dart'),
      );
      final back = await store.read('loop');

      expect(back!.tabs, ['b.dart', 'src/a.dart', 'c.dart']);
      expect(back.active, 'src/a.dart');
    });

    test('a project with no memory gives null', () async {
      expect(await OpenFilesStore().read('new_project'), isNull);
    });

    test('projects do not mix their files up', () async {
      final store = OpenFilesStore();
      await store.write('a', const OpenFiles(tabs: ['one.dart'], active: 'one.dart'));
      await store.write('b', const OpenFiles(tabs: ['two.dart'], active: null));

      expect((await store.read('a'))!.tabs, ['one.dart']);
      expect((await store.read('b'))!.tabs, ['two.dart']);
      expect((await store.read('b'))!.active, isNull);
    });

    test('damaged preferences mean "nothing remembered"', () async {
      SharedPreferences.setMockInitialValues({
        'open_files_bad': 'this is not json',
        'open_files_odd': '["a list, not a map"]',
      });

      expect(await OpenFilesStore().read('bad'), isNull);
      expect(await OpenFilesStore().read('odd'), isNull);
    });
  });
}
