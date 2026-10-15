import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per project, which file was open last (its relative path),
/// so opening the project again brings that file back.
class LastFileStore {
  static String _key(Object projectId) => 'last_file_$projectId';

  Future<String?> read(Object projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(projectId));
  }

  Future<void> write(Object projectId, String relativePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectId), relativePath);
  }
}
