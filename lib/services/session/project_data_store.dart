import 'package:shared_preferences/shared_preferences.dart';

import 'last_project_store.dart';

/// What the app remembers about a project (its open files, the cursor
/// positions, being the project that was open last) is filed under the
/// project's id, which is its folder name. When a project is renamed all of
/// that has to move to the new name; when it is deleted it has to go.
class ProjectDataStore {
  static const _keyPrefixes = ['open_files_', 'cursors_'];

  Future<void> rename(String oldId, String newId) async {
    if (oldId == newId) return;
    final prefs = await SharedPreferences.getInstance();
    for (final prefix in _keyPrefixes) {
      final value = prefs.getString('$prefix$oldId');
      if (value == null) continue;
      await prefs.setString('$prefix$newId', value);
      await prefs.remove('$prefix$oldId');
    }
    final last = LastProjectStore();
    if (await last.read() == oldId) await last.write(newId);
  }

  Future<void> forget(String id) async {
    final prefs = await SharedPreferences.getInstance();
    for (final prefix in _keyPrefixes) {
      await prefs.remove('$prefix$id');
    }
    final last = LastProjectStore();
    if (await last.read() == id) await last.clear();
  }
}
