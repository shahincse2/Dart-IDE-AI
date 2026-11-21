import 'package:dartlab/services/session/cursor_store.dart';
import 'package:dartlab/services/session/last_project_store.dart';
import 'package:dartlab/services/session/project_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> stored(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  group('ProjectDataStore.rename', () {
    test('moves the open files, the cursors and the last project', () async {
      SharedPreferences.setMockInitialValues({
        'open_files_Old': 'tabs',
        'cursors_Old': '{"main.dart":4}',
        'last_project_id': 'Old',
      });

      await ProjectDataStore().rename('Old', 'New');

      expect(await stored('open_files_New'), 'tabs');
      expect(await stored('open_files_Old'), isNull);
      expect(await CursorStore().read('New'), {'main.dart': 4});
      expect(await stored('cursors_Old'), isNull);
      expect(await LastProjectStore().read(), 'New');
    });

    test('leaves other projects alone, even as the last project', () async {
      SharedPreferences.setMockInitialValues({
        'open_files_Old': 'a',
        'open_files_Other': 'b',
        'last_project_id': 'Other',
      });

      await ProjectDataStore().rename('Old', 'New');

      expect(await stored('open_files_Other'), 'b');
      expect(await LastProjectStore().read(), 'Other');
    });

    test('a project with nothing remembered is fine, and the same name changes nothing', () async {
      SharedPreferences.setMockInitialValues({'open_files_Same': 'x'});

      await ProjectDataStore().rename('Missing', 'New');
      await ProjectDataStore().rename('Same', 'Same');

      expect(await stored('open_files_New'), isNull);
      expect(await stored('open_files_Same'), 'x');
    });
  });

  group('ProjectDataStore.forget', () {
    test('removes everything remembered, and the last project if it was this one', () async {
      SharedPreferences.setMockInitialValues({
        'open_files_Gone': 'a',
        'cursors_Gone': '{}',
        'open_files_Kept': 'b',
        'last_project_id': 'Gone',
      });

      await ProjectDataStore().forget('Gone');

      expect(await stored('open_files_Gone'), isNull);
      expect(await stored('cursors_Gone'), isNull);
      expect(await stored('open_files_Kept'), 'b');
      expect(await LastProjectStore().read(), isNull);
    });

    test('keeps the last project when it is another one', () async {
      SharedPreferences.setMockInitialValues({'last_project_id': 'Kept'});

      await ProjectDataStore().forget('Gone');

      expect(await LastProjectStore().read(), 'Kept');
    });
  });
}
