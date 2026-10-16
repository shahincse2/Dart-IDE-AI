import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The files a project had open: its tabs, in order, and the active one.
class OpenFiles {
  const OpenFiles({required this.tabs, required this.active});

  final List<String> tabs;
  final String? active;

  String encode() => jsonEncode({'tabs': tabs, 'active': active});

  /// Reads what [encode] wrote. Anything unreadable gives null, so damaged
  /// preferences just mean "nothing remembered".
  static OpenFiles? decode(String? text) {
    if (text == null) return null;
    try {
      final data = jsonDecode(text);
      if (data is! Map) return null;
      final tabs = data['tabs'];
      final active = data['active'];
      return OpenFiles(
        tabs: tabs is List ? tabs.whereType<String>().toList() : <String>[],
        active: active is String ? active : null,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Saves and loads [OpenFiles] per project.
class OpenFilesStore {
  static String _key(Object projectId) => 'open_files_$projectId';

  Future<OpenFiles?> read(Object projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return OpenFiles.decode(prefs.getString(_key(projectId)));
  }

  Future<void> write(Object projectId, OpenFiles files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectId), files.encode());
  }
}
