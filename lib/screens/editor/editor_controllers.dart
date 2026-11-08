import 'package:flutter/material.dart';

import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/themes.dart';
import '../../widgets/code_editor_controller.dart';

/// One editor controller (and undo history) for every open tab, kept matched
/// to [FileProvider.openTabs]: controllers of closed tabs are disposed, and a
/// newly opened tab gets one, loaded with the file's text.
class EditorControllers {
  EditorControllers({
    required FileProvider files,
    required SettingsProvider Function() settings,
    required bool Function() isAlive,
    required VoidCallback onChanged,
  })  : _files = files,
        _settings = settings,
        _isAlive = isAlive,
        _onChanged = onChanged;

  final FileProvider _files;
  final SettingsProvider Function() _settings;
  final bool Function() _isAlive;
  final VoidCallback _onChanged;

  final Map<String, CodeEditorController> controllers = {};
  final Map<String, UndoHistoryController> undoControllers = {};

  /// Command-line arguments per file, for the next run.
  final Map<String, List<String>> args = {};
  final Set<String> _loading = {};

  /// The path of the file being edited, if any.
  String? get activePath => _files.activeTab;

  CodeEditorController? of(String? path) =>
      path == null ? null : controllers[path];

  UndoHistoryController? undoOf(String? path) =>
      path == null ? null : undoControllers[path];

  /// Runs [action] on the file being edited; does nothing when none is open.
  void withActive(
    void Function(String path, CodeEditorController controller) action,
  ) {
    final path = _files.activeTab;
    final controller = of(path);
    if (path != null && controller != null) action(path, controller);
  }

  /// Disposes controllers for tabs that closed, and creates + loads one for any
  /// newly opened tab.
  Future<void> sync() async {
    final openTabs = _files.openTabs;

    final toRemove =
        controllers.keys.where((path) => !openTabs.contains(path)).toList();
    for (final path in toRemove) {
      controllers.remove(path)?.dispose();
      undoControllers.remove(path)?.dispose();
      args.remove(path);
    }

    for (final path in openTabs) {
      if (controllers.containsKey(path) || _loading.contains(path)) {
        continue;
      }
      _loading.add(path);

      final settings = _settings();
      final controller = CodeEditorController(
        scheme: editorSchemeFromName(settings.editorThemeName),
        indentSize: settings.indentSize,
      );

      final content = await _files.readFile(path);

      if (!_isAlive() || !_files.openTabs.contains(path)) {
        // The tab was closed again while this read was in flight —
        // discard rather than attach a controller for a closed tab.
        _loading.remove(path);
        controller.dispose();
        continue;
      }

      controller.value = TextEditingValue(
        text: content,
        selection: const TextSelection.collapsed(offset: 0),
      );
      controller.addListener(
        () => _files.scheduleAutoSave(path, controller.text),
      );

      controllers[path] = controller;
      undoControllers[path] = UndoHistoryController();
      _loading.remove(path);
      if (_isAlive()) _onChanged();
    }
  }

  /// Every open controller stays in sync with live settings, not just the
  /// active one — otherwise switching to a background tab would briefly show
  /// stale theme/indent settings.
  void applySettings(SettingsProvider settings) {
    for (final controller in controllers.values) {
      controller.scheme = editorSchemeFromName(settings.editorThemeName);
      controller.indentSize = settings.indentSize;
    }
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final undoController in undoControllers.values) {
      undoController.dispose();
    }
  }
}
