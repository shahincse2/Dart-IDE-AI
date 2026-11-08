import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../widgets/editor_body.dart';
import '../widgets/file_tree.dart';
import 'editor/editor_app_bar.dart';
import 'editor/editor_commands.dart';
import 'editor/editor_controllers.dart';
import 'editor/editor_file_commands.dart';
import 'editor/editor_shortcuts.dart';
import 'editor/run_error_marker.dart';

/// The main workspace. This screen owns the responsive shell described
/// in Section 44:
///   - Portrait: drawer for file navigation, editor fills the rest.
///   - Landscape / tablet: persistent sidebar beside the editor.
///
/// It wires the pieces together: one editor controller per open tab
/// ([EditorControllers]), what the editor can do ([EditorCommands], used by the
/// app bar and the keyboard shortcuts alike), the app bar ([EditorAppBar]) and
/// the error line marker for the file that ran ([RunErrorMarker]).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final FileProvider _files;
  late final RunnerProvider _runner;
  late final EditorControllers _editors;
  late final RunErrorMarker _errorMarker;
  late final EditorCommands _commands;

  bool _showFindReplace = false;
  bool _findReplaceExpanded = false;

  @override
  void initState() {
    super.initState();
    _files = context.read<FileProvider>();
    _runner = context.read<RunnerProvider>();
    _editors = EditorControllers(
      files: _files,
      settings: () => context.read<SettingsProvider>(),
      isAlive: () => mounted,
      onChanged: () => setState(() {}),
    );
    _errorMarker = RunErrorMarker(runner: _runner, controllerFor: _editors.of);
    _commands = EditorCommands(
      context: () => context,
      runner: _runner,
      editors: _editors,
      errorMarker: _errorMarker,
      file: EditorFileCommands(
        context: () => context,
        files: _files,
        editors: _editors,
      ),
    );

    _files.addListener(_onFilesChanged);
    _editors.sync();
    _runner.addListener(_errorMarker.onRunnerChanged);
  }

  void _onFilesChanged() => _editors.sync();

  /// Ctrl+F / Ctrl+H: unlike the app bar's search icon (a toggle), a keyboard
  /// shortcut should *open* Find — pressing it again while already open
  /// shouldn't close the bar out from under someone still typing a query.
  void _openFind({required bool expandReplace}) {
    if (_files.activeTab == null) return;
    setState(() {
      _showFindReplace = true;
      _findReplaceExpanded = expandReplace;
    });
  }

  void _toggleFind() => setState(() {
        if (_showFindReplace) {
          _showFindReplace = false;
        } else {
          _showFindReplace = true;
          _findReplaceExpanded = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isRunning = context.select<RunnerProvider, bool>((r) => r.isRunning);
    final files = context.watch<FileProvider>();
    _editors.applySettings(settings);

    final activePath = files.activeTab;
    final controller = _editors.of(activePath);
    final useSidebar =
        AppConstants.isTablet(context) || AppConstants.isLandscape(context);

    final editorArea = EditorBody(
      controller: controller,
      undoController: _editors.undoOf(activePath),
      fontSize: settings.editorFontSize,
      wordWrap: settings.wordWrap,
      showFindReplace: _showFindReplace && controller != null,
      findReplaceExpanded: _findReplaceExpanded,
      onCloseFindReplace: () => setState(() => _showFindReplace = false),
    );

    final scaffold = Scaffold(
      appBar: EditorAppBar(
        fileName: files.activeFileName ?? 'No file open',
        filePath: activePath == null
            ? null
            : [files.currentProject?.name, activePath]
                .whereType<String>()
                .join('/'),
        isDirty: activePath != null && files.isDirty(activePath),
        useSidebar: useSidebar,
        isRunning: isRunning,
        wordWrap: settings.wordWrap,
        actions: _commands.toActions(
          hasFile: controller != null,
          onToggleFind: _toggleFind,
        ),
      ),
      drawer: useSidebar ? null : const Drawer(child: FileTreeView()),
      body: SafeArea(
        child: useSidebar
            ? Row(
                children: [
                  const SizedBox(width: 240, child: FileTreeView()),
                  const VerticalDivider(width: 0.5),
                  Expanded(child: editorArea),
                ],
              )
            : editorArea,
      ),
    );

    return CallbackShortcuts(
      bindings: editorShortcuts(
        onSave: _commands.file.save,
        onRunOrStop: _commands.runOrStop,
        onOpenFind: _openFind,
        onGoToLine: _commands.goToLine,
        onFormat: _commands.format,
      ),
      child: Focus(
        autofocus: true,
        // A plain Focus with no visual affordance — its only job is to
        // hold initial focus so keyboard shortcuts work immediately,
        // before the user has tapped into the editor at all.
        child: scaffold,
      ),
    );
  }

  @override
  void dispose() {
    _files.removeListener(_onFilesChanged);
    _files.flushAllPendingSaves();
    _runner.removeListener(_errorMarker.onRunnerChanged);
    _editors.dispose();
    super.dispose();
  }
}
