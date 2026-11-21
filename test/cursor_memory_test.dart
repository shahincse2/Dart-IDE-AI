import 'package:dart_ide/services/session/cursor_memory.dart';
import 'package:dart_ide/services/session/cursor_store.dart';
import 'package:dart_ide/services/session/last_project_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A memory that waits this long before writing (short, for the tests).
CursorMemory quickMemory() =>
    CursorMemory(delay: const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CursorStore.decode', () {
    test('reads what was written', () {
      expect(CursorStore.decode('{"a.dart":5,"lib/b.dart":0}'),
          {'a.dart': 5, 'lib/b.dart': 0});
    });

    test('nothing, or damaged text, means nothing remembered', () {
      expect(CursorStore.decode(null), isEmpty);
      expect(CursorStore.decode('not json'), isEmpty);
      expect(CursorStore.decode('[1,2]'), isEmpty);
    });

    test('values that are not offsets are dropped', () {
      expect(
          CursorStore.decode(
              '{"a.dart":5,"b.dart":"x","c.dart":-3,"d.dart":1.5}'),
          {'a.dart': 5});
    });
  });

  group('CursorMemory', () {
    test('nothing is remembered at first', () async {
      final memory = quickMemory();
      await memory.useProject('Demo');

      expect(memory.cursorOf('main.dart'), isNull);
      memory.dispose();
    });

    test('a cursor is remembered, and written to the next run of the app',
        () async {
      final memory = quickMemory();
      await memory.useProject('Demo');
      memory.record('main.dart', 42);
      await memory.flush();

      final nextRun = quickMemory();
      await nextRun.useProject('Demo');

      expect(nextRun.cursorOf('main.dart'), 42);
      memory.dispose();
      nextRun.dispose();
    });

    test('after a pause it writes by itself', () async {
      final memory = quickMemory();
      await memory.useProject('Demo');
      memory.record('main.dart', 7);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(await CursorStore().read('Demo'), {'main.dart': 7});
      memory.dispose();
    });

    test('the last cursor wins', () async {
      final memory = quickMemory();
      await memory.useProject('Demo');
      memory.record('main.dart', 1);
      memory.record('main.dart', 2);
      memory.record('main.dart', 3);
      await memory.flush();

      expect(await CursorStore().read('Demo'), {'main.dart': 3});
      memory.dispose();
    });

    test('projects do not mix', () async {
      final memory = quickMemory();
      await memory.useProject('One');
      memory.record('main.dart', 10);
      await memory.useProject('Two');
      memory.record('main.dart', 20);
      await memory.flush();

      expect(await CursorStore().read('One'), {'main.dart': 10});
      expect(await CursorStore().read('Two'), {'main.dart': 20});
      expect(memory.cursorOf('main.dart'), 20);
      memory.dispose();
    });

    test('going back to a project brings its cursors back', () async {
      final memory = quickMemory();
      await memory.useProject('One');
      memory.record('a.dart', 5);
      await memory.useProject('Two');
      await memory.useProject('One');

      expect(memory.cursorOf('a.dart'), 5);
      memory.dispose();
    });

    test('nothing is recorded before a project is chosen, or for a bad offset',
        () async {
      final memory = quickMemory();
      memory.record('main.dart', 5);
      await memory.useProject('Demo');
      memory.record('main.dart', -1);
      await memory.flush();

      expect(memory.cursorOf('main.dart'), isNull);
      expect(await CursorStore().read('Demo'), isEmpty);
      memory.dispose();
    });

    test('asking again for the same project does not forget what was recorded',
        () async {
      final memory = quickMemory();
      await memory.useProject('Demo');
      memory.record('main.dart', 9);

      await memory.useProject('Demo');

      expect(memory.cursorOf('main.dart'), 9);
      memory.dispose();
    });
  });

  group('LastProjectStore', () {
    test('nothing at first, then what was written', () async {
      final store = LastProjectStore();
      expect(await store.read(), isNull);

      await store.write('Demo');
      expect(await store.read(), 'Demo');

      await store.write('Other');
      expect(await store.read(), 'Other');
    });
  });
}
