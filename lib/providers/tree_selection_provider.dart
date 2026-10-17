import 'package:flutter/foundation.dart';

import '../models/tree_entry_ref.dart';

/// The files and folders ticked in the file tree while the user selects
/// several at once (to copy or move them together).
///
/// The selection belongs to one project; for any other project it counts as
/// empty, so switching projects needs no clean-up.
class TreeSelection extends ChangeNotifier {
  Object? _projectId;
  final Map<String, bool> _items = {}; // relative path -> is it a folder?

  bool isActive(Object? projectId) =>
      _projectId == projectId && _items.isNotEmpty;

  bool isSelected(Object? projectId, String path) =>
      _projectId == projectId && _items.containsKey(path);

  int countFor(Object? projectId) => _projectId == projectId ? _items.length : 0;

  List<TreeEntryRef> entriesFor(Object? projectId) {
    if (_projectId != projectId) return const [];
    return [
      for (final item in _items.entries)
        TreeEntryRef(item.key, isFolder: item.value),
    ];
  }

  /// Starts a selection with [entry] as its first item.
  void begin(Object? projectId, TreeEntryRef entry) {
    _projectId = projectId;
    _items
      ..clear()
      ..[entry.path] = entry.isFolder;
    notifyListeners();
  }

  /// Adds [entry] if it is not selected, removes it if it is.
  void toggle(TreeEntryRef entry) {
    if (_items.remove(entry.path) == null) _items[entry.path] = entry.isFolder;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
