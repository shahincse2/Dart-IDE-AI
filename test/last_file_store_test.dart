import 'package:dartlab/services/last_file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LastFileStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('remembers the file of a project', () async {
      final store = LastFileStore();

      await store.write('loop', 'src/main.dart');

      expect(await store.read('loop'), 'src/main.dart');
    });

    test('a project with no memory gives null', () async {
      expect(await LastFileStore().read('new_project'), isNull);
    });

    test('projects do not mix their files up', () async {
      final store = LastFileStore();
      await store.write('a', 'one.dart');
      await store.write('b', 'two.dart');

      expect(await store.read('a'), 'one.dart');
      expect(await store.read('b'), 'two.dart');
    });

    test('the newest file replaces the old one', () async {
      final store = LastFileStore();
      await store.write('a', 'old.dart');
      await store.write('a', 'new.dart');

      expect(await store.read('a'), 'new.dart');
    });
  });
}
