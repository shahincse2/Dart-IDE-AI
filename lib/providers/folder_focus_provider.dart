import 'package:flutter/foundation.dart';

/// The folder the user last tapped in the file tree. It is highlighted like
/// the open file is, and it is where "Import file" puts a file.
///
/// The focus belongs to a project and to the file that was open when the
/// folder was tapped. Once another file becomes the open one, the focus no
/// longer counts (only one row is highlighted at a time).
class FolderFocus extends ChangeNotifier {
  Object? _projectId;
  String? _folder;
  String? _activeTab;

  /// The focused folder of [projectId], or null if none counts right now.
  String? folderFor(Object? projectId, String? activeTab) {
    final stillValid = _projectId == projectId && _activeTab == activeTab;
    return stillValid ? _folder : null;
  }

  void focus(Object? projectId, String folder, String? activeTab) {
    _projectId = projectId;
    _folder = folder;
    _activeTab = activeTab;
    notifyListeners();
  }
}
