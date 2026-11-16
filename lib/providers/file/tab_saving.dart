import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import 'open_tabs.dart';

/// Per-tab dirty state and saving for [FileProvider]: autosave while typing,
/// save now, and flushing before a tab closes or its file moves.
mixin TabSaving on ChangeNotifier, OpenTabs {
  final Map<String, bool> _dirtyTabs = {};
  final Map<String, String> _pendingContent = {};
  final Map<String, Timer> _autoSaveTimers = {};

  bool isDirty(String relativePath) => _dirtyTabs[relativePath] ?? false;

  /// Closes a tab. Confirming with the user when it's dirty is the
  /// caller's job (Section 19) — by the time this runs, that decision
  /// has already been made. [flush] controls whether pending content
  /// gets written first (true = "save and close", false = "discard").
  Future<void> closeTab(String relativePath, {required bool flush}) async {
    _autoSaveTimers.remove(relativePath)?.cancel();
    if (flush) {
      final pending = _pendingContent.remove(relativePath);
      if (pending != null && (_dirtyTabs[relativePath] ?? false)) {
        await _writeNow(relativePath, pending);
      }
    } else {
      _pendingContent.remove(relativePath);
    }
    _dirtyTabs.remove(relativePath);

    removeOpenTab(relativePath);
    notifyListeners();
  }

  @protected
  Future<void> closeAllTabs({required bool flush}) async {
    for (final path in List<String>.from(openTabs)) {
      await closeTab(path, flush: flush);
    }
  }

  /// Called on every editor keystroke for whichever tab is being
  /// edited. Debounces so typing doesn't hit disk on every character
  /// (Section 22). Each open tab has its own independent timer, so
  /// switching the active tab never interferes with another tab's
  /// pending save.
  void scheduleAutoSave(String relativePath, String content) {
    if (currentProject == null) return;
    _dirtyTabs[relativePath] = true;
    _pendingContent[relativePath] = content;
    notifyListeners();

    _autoSaveTimers[relativePath]?.cancel();
    _autoSaveTimers[relativePath] = Timer(AppConstants.autoSaveDebounce, () {
      unawaited(_writeNow(relativePath, content));
    });
  }

  Future<void> saveNow(String relativePath, String content) =>
      _writeNow(relativePath, content);

  Future<void> flushPendingSave(String relativePath) async {
    _autoSaveTimers.remove(relativePath)?.cancel();
    final pending = _pendingContent[relativePath];
    if (pending != null && (_dirtyTabs[relativePath] ?? false)) {
      await _writeNow(relativePath, pending);
    }
  }

  /// Flushes every open tab — used when leaving the editor entirely
  /// (Section 22's "app lifecycle-এর সময় final save").
  Future<void> flushAllPendingSaves() async {
    for (final path in List<String>.from(openTabs)) {
      await flushPendingSave(path);
    }
  }

  Future<void> _writeNow(String relativePath, String content) async {
    final project = currentProject;
    if (project == null) return;
    await fileService.writeFile(project, relativePath, content);
    _pendingContent.remove(relativePath);
    _dirtyTabs[relativePath] = false;
    notifyListeners();
  }

  /// Stops every pending autosave timer (the provider is being disposed).
  @protected
  void cancelAutoSaveTimers() {
    for (final timer in _autoSaveTimers.values) {
      timer.cancel();
    }
  }

  // ---- For moving, renaming and deleting files ----

  @protected
  Future<void> flushTabsOn(
    String relativePath, {
    required bool isFolder,
  }) async {
    for (final tab in tabsOn(relativePath, isFolder: isFolder)) {
      await flushPendingSave(tab);
    }
  }

  /// Open tabs on [oldPath] (or, for a folder, below it) now live at
  /// [newPath]: their paths and per-tab save state move along.
  @protected
  void followToNewPath(
    String oldPath,
    String newPath, {
    required bool isFolder,
  }) {
    if (!isFolder) {
      _moveTab(oldPath, newPath);
      return;
    }
    final oldPrefix = '$oldPath/';
    final newPrefix = '$newPath/';
    for (final oldTabPath in List<String>.from(openTabs)) {
      if (oldTabPath.startsWith(oldPrefix)) {
        _moveTab(
          oldTabPath,
          newPrefix + oldTabPath.substring(oldPrefix.length),
        );
      }
    }
  }

  void _moveTab(String oldPath, String newPath) {
    if (!renameOpenTab(oldPath, newPath)) return;
    if (_dirtyTabs.containsKey(oldPath)) {
      _dirtyTabs[newPath] = _dirtyTabs.remove(oldPath)!;
    }
    if (_pendingContent.containsKey(oldPath)) {
      _pendingContent[newPath] = _pendingContent.remove(oldPath)!;
    }
    if (_autoSaveTimers.containsKey(oldPath)) {
      _autoSaveTimers[newPath] = _autoSaveTimers.remove(oldPath)!;
    }
  }
}
