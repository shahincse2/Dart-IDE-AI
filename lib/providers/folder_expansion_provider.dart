import 'package:flutter/foundation.dart';

/// Which folders of the file tree the user has collapsed. Folders are open
/// by default.
///
/// It lives in a provider, not in the tree's widgets, so a folder stays
/// closed when the tree is rebuilt or moved (drawer <-> sidebar, rotation).
class FolderExpansion extends ChangeNotifier {
  final Set<String> _collapsed = {};

  bool isExpanded(String key) => !_collapsed.contains(key);

  void toggle(String key) {
    if (!_collapsed.remove(key)) _collapsed.add(key);
    notifyListeners();
  }
}
