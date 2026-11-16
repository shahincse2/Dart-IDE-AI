import 'package:shared_preferences/shared_preferences.dart';

/// Which project was open last, so the app can open it again at the next
/// start.
class LastProjectStore {
  static const _key = 'last_project_id';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, projectId);
  }
}
