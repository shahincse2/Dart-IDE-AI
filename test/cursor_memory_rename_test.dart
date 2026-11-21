import 'package:dart_ide/services/session/cursor_memory.dart';
import 'package:dart_ide/services/session/cursor_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CursorMemory quickMemory() =>
    CursorMemory(delay: const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CursorMemory.renameProject', () {
    test('keeps what is remembered and writes under the new name from then on', () async {
      final memory = quickMemory();
      await memory.useProject('Old');
      memory.record('a.dart', 3);

      memory.renameProject('Old', 'New');
      memory.record('b.dart', 8);
      await memory.flush();

      expect(memory.cursorOf('a.dart'), 3);
      expect(await CursorStore().read('New'), {'a.dart': 3, 'b.dart': 8});
      expect(await CursorStore().read('Old'), isEmpty);
      memory.dispose();
    });

    test('another project being renamed changes nothing here', () async {
      final memory = quickMemory();
      await memory.useProject('Mine');

      memory.renameProject('Other', 'Renamed');
      memory.record('a.dart', 1);
      await memory.flush();

      expect(await CursorStore().read('Mine'), {'a.dart': 1});
      memory.dispose();
    });
  });

  group('CursorMemory.forgetProject', () {
    test('nothing is written for a deleted project, even what was waiting', () async {
      final memory = quickMemory();
      await memory.useProject('Gone');
      memory.record('a.dart', 5);

      memory.forgetProject('Gone');
      await memory.flush();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(await CursorStore().read('Gone'), isEmpty);
      expect(memory.cursorOf('a.dart'), isNull);
      memory.dispose();
    });

    test('another project being deleted changes nothing here', () async {
      final memory = quickMemory();
      await memory.useProject('Mine');
      memory.record('a.dart', 2);

      memory.forgetProject('Other');
      await memory.flush();

      expect(await CursorStore().read('Mine'), {'a.dart': 2});
      memory.dispose();
    });
  });
}
