import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the cursor was in each file of a project, as character offsets
/// (the path of the file inside the project -> the offset).
class CursorStore {
  static String _key(Object projectId) => 'cursors_$projectId';

  Future<Map<String, int>> read(Object projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(_key(projectId)));
  }

  Future<void> write(Object projectId, Map<String, int> cursors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectId), jsonEncode(cursors));
  }

  /// Reads what [write] wrote. Anything unreadable gives an empty map, so
  /// damaged preferences just mean "nothing remembered".
  static Map<String, int> decode(String? text) {
    if (text == null) return {};
    try {
      final data = jsonDecode(text);
      if (data is! Map) return {};
      return {
        for (final entry in data.entries)
          if (entry.key is String && entry.value is int && entry.value >= 0)
            entry.key as String: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }
}
