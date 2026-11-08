import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/runner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/font_size_dialog.dart';
import '../../widgets/format_action.dart';
import '../../widgets/go_to_line_dialog.dart';
import '../../widgets/variable_inspector_panel.dart';
import '../git_screen.dart';
import '../settings_screen.dart';
import '../ui_preview_screen.dart';
import 'editor_actions.dart';
import 'editor_controllers.dart';
import 'editor_file_commands.dart';
import 'run_error_marker.dart';

/// Everything the editor screen can do, implemented once: the app bar buttons
/// and the keyboard shortcuts both call these. The file actions (save, export,
/// share ...) are in [EditorFileCommands].
class EditorCommands {
  EditorCommands({
    required BuildContext Function() context,
    required RunnerProvider runner,
    required EditorControllers editors,
    required RunErrorMarker errorMarker,
    required this.file,
  })  : _context = context,
        _runner = runner,
        _editors = editors,
        _errorMarker = errorMarker;

  final BuildContext Function() _context;
  final RunnerProvider _runner;
  final EditorControllers _editors;
  final RunErrorMarker _errorMarker;
  final EditorFileCommands file;

  void runOrStop() {
    final path = _editors.activePath;
    final controller = _editors.of(path);
    if (controller == null) return;
    if (_runner.isRunning) {
      _runner.stop();
      return;
    }
    controller.setErrorLine(null);
    _errorMarker.beginRun(path);
    _runner.run(controller.text, args: _editors.args[path] ?? const []);
  }

  void goToLine() => _editors.withActive((_, c) => showGoToLineDialog(_context(), c));

  /// Format the whole file (the Format code menu item, and Ctrl+Alt+L).
  void format() => _editors.withActive((_, c) => formatWithMessage(_context(), c));

  void foldAll() => _editors.withActive((_, c) => c.foldAll());

  void unfoldAll() => _editors.withActive((_, c) => c.unfoldAll());

  void previewUi() => _editors.withActive(
        (_, c) => Navigator.of(_context()).push(
          MaterialPageRoute(builder: (_) => UiPreviewScreen(source: c.text)),
        ),
      );

  void inspect() {
    showModalBottomSheet(
      context: _context(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VariableInspectorPanel(),
    );
  }

  void git() => _editors.withActive(
        (path, c) => Navigator.of(_context()).push(
          MaterialPageRoute(
            builder: (_) =>
                GitScreen(fileContent: c.text, fileName: fileNameOf(path)),
          ),
        ),
      );

  void settings() => Navigator.of(_context())
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void toggleWordWrap() {
    final s = _context().read<SettingsProvider>();
    s.setWordWrap(!s.wordWrap);
  }

  void fontSize() {
    final context = _context();
    showFontSizeDialog(context, context.read<SettingsProvider>());
  }

  /// What the app bar can do right now: no file open means no file actions.
  /// [onToggleFind] belongs to the screen (it shows the find bar).
  EditorActions toActions({
    required bool hasFile,
    required VoidCallback onToggleFind,
  }) {
    VoidCallback? ifFile(VoidCallback action) => hasFile ? action : null;
    return EditorActions(
      run: ifFile(runOrStop),
      save: ifFile(file.save),
      find: ifFile(onToggleFind),
      goToLine: ifFile(goToLine),
      format: ifFile(format),
      foldAll: ifFile(foldAll),
      unfoldAll: ifFile(unfoldAll),
      export: ifFile(file.export),
      importFile: file.importFile,
      shareCode: ifFile(file.shareCode),
      printCode: ifFile(file.printCode),
      sharePdf: ifFile(file.sharePdf),
      previewUi: ifFile(previewUi),
      inspect: inspect,
      git: ifFile(git),
      settings: settings,
      toggleWordWrap: toggleWordWrap,
      fontSize: fontSize,
    );
  }
}
