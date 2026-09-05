import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/console_event.dart';
import '../providers/file_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/runner_error_parser.dart';
import '../utils/themes.dart';
import '../widgets/arguments_dialog.dart';
import '../widgets/code_editor.dart';
import '../widgets/code_editor_controller.dart';
import '../widgets/coding_toolbar.dart';
import '../widgets/console_panel.dart';
import '../widgets/file_tab_bar.dart';
import '../widgets/file_tree.dart';
import '../widgets/find_replace_bar.dart';
import '../widgets/font_size_dialog.dart';
import '../widgets/go_to_line_dialog.dart';
import 'ui_preview_screen.dart';

/// The main workspace. This screen owns the responsive shell described
/// in Section 44:
///   - Portrait: drawer for file navigation, editor fills the rest.
///   - Landscape / tablet: persistent sidebar beside the editor.
///
/// What's real as of Phase 9: "Preview UI" (app bar's overflow menu)
/// interprets the current file as a Flutter UI script — a top-level
/// `Widget build(BuildContext context)` function — via
/// `tom_d4rt_flutter`, rendering a genuine, live widget tree
/// full-screen (real Material widgets, real state/gestures), not a
/// mock. Honest limitation: this runs on the main isolate (Widgets
/// can't cross an Isolate boundary the way console output can), so
/// there's no Isolate-based Stop for it the way DartRunnerService has
/// — see ui_runner_service.dart. Plus everything from Phases 2-8,
/// including Phase 8's own honest gap: interactive stdin, still not
/// implemented after finding no confirmed way to intercept it.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final FileProvider _fileProvider;
  late final RunnerProvider _runnerProvider;
  final Map<String, CodeEditorController> _controllers = {};
  final Map<String, UndoHistoryController> _undoControllers = {};
  final Map<String, List<String>> _argsByPath = {};
  final Set<String> _loadingPaths = {};
  bool _showFindReplace = false;
  String? _lastRunPath;
  int _lastSeenRunnerEventCount = 0;

  @override
  void initState() {
    super.initState();
    _fileProvider = context.read<FileProvider>();
    _fileProvider.addListener(_onFileProviderChanged);
    _syncControllers();

    _runnerProvider = context.read<RunnerProvider>();
    _runnerProvider.addListener(_onRunnerChanged);
  }

  void _onFileProviderChanged() => _syncControllers();

  /// Looks for a line number in any new stderr output and, if found,
  /// marks it on whichever file was actually running (Section 35) —
  /// best-effort, see runner_error_parser.dart for why this can't be
  /// guaranteed to always find one.
  void _onRunnerChanged() {
    final events = _runnerProvider.events;
    if (events.length > _lastSeenRunnerEventCount) {
      final newEvents = events.sublist(_lastSeenRunnerEventCount);
      final runPath = _lastRunPath;
      if (runPath != null) {
        for (final event in newEvents) {
          if (event.type == ConsoleEventType.stderr) {
            final line = parseErrorLine(event.text ?? '');
            if (line != null) {
              _controllers[runPath]?.setErrorLine(line);
              break;
            }
          }
        }
      }
    }
    _lastSeenRunnerEventCount = events.length;
  }

  /// Keeps [_controllers] matched to [FileProvider.openTabs]: disposes
  /// controllers for tabs that closed, and creates + loads one for any
  /// newly opened tab.
  Future<void> _syncControllers() async {
    final openTabs = _fileProvider.openTabs;

    final toRemove = _controllers.keys.where((path) => !openTabs.contains(path)).toList();
    for (final path in toRemove) {
      _controllers.remove(path)?.dispose();
      _undoControllers.remove(path)?.dispose();
      _argsByPath.remove(path);
    }

    for (final path in openTabs) {
      if (_controllers.containsKey(path) || _loadingPaths.contains(path)) continue;
      _loadingPaths.add(path);

      final settings = context.read<SettingsProvider>();
      final controller = CodeEditorController(
        scheme: editorSchemeFromName(settings.editorThemeName),
        indentSize: settings.indentSize,
      );

      final content = await _fileProvider.readFile(path);

      if (!mounted || !_fileProvider.openTabs.contains(path)) {
        // The tab was closed again while this read was in flight —
        // discard rather than attach a controller for a closed tab.
        _loadingPaths.remove(path);
        controller.dispose();
        continue;
      }

      controller.value = TextEditingValue(
        text: content,
        selection: const TextSelection.collapsed(offset: 0),
      );
      controller.addListener(() => _fileProvider.scheduleAutoSave(path, controller.text));

      _controllers[path] = controller;
      _undoControllers[path] = UndoHistoryController();
      _loadingPaths.remove(path);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _fileProvider.removeListener(_onFileProviderChanged);
    _fileProvider.flushAllPendingSaves();
    _runnerProvider.removeListener(_onRunnerChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final undoController in _undoControllers.values) {
      undoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final runner = context.watch<RunnerProvider>();
    final fileProvider = context.watch<FileProvider>();

    // Every open controller stays in sync with live settings, not just
    // the active one — otherwise switching to a background tab would
    // briefly show stale theme/indent settings.
    for (final controller in _controllers.values) {
      controller.scheme = editorSchemeFromName(settings.editorThemeName);
      controller.indentSize = settings.indentSize;
    }

    final activePath = fileProvider.activeTab;
    final activeController = activePath != null ? _controllers[activePath] : null;
    final activeUndoController = activePath != null ? _undoControllers[activePath] : null;

    final isTablet = AppConstants.isTablet(context);
    final isLandscape = AppConstants.isLandscape(context);
    final useSidebar = isTablet || isLandscape;

    final editorArea = _EditorBody(
      controller: activeController,
      undoController: activeUndoController,
      fontSize: settings.editorFontSize,
      wordWrap: settings.wordWrap,
      showFindReplace: _showFindReplace && activeController != null,
      onCloseFindReplace: () => setState(() => _showFindReplace = false),
    );

    return Scaffold(
      appBar: _EditorAppBar(
        fileName: fileProvider.activeFileName ?? 'No file open',
        isDirty: activePath != null && fileProvider.isDirty(activePath),
        useSidebar: useSidebar,
        isRunning: runner.isRunning,
        onRunPressed: activeController == null
            ? null
            : () {
                if (runner.isRunning) {
                  runner.stop();
                } else {
                  activeController.setErrorLine(null);
                  _lastRunPath = activePath;
                  _lastSeenRunnerEventCount = 0;
                  runner.run(activeController.text, args: _argsByPath[activePath] ?? const []);
                }
              },
        onSavePressed: activeController != null
            ? () => fileProvider.saveNow(activePath!, activeController.text)
            : null,
        onFindPressed: activeController != null
            ? () => setState(() => _showFindReplace = !_showFindReplace)
            : null,
        onGoToLinePressed: activeController != null
            ? () => showGoToLineDialog(context, activeController)
            : null,
        onArgumentsPressed: activeController != null
            ? () async {
                final current = _argsByPath[activePath]?.join(' ') ?? '';
                final result = await showArgumentsDialog(context, current);
                if (result != null) setState(() => _argsByPath[activePath!] = result);
              }
            : null,
        argsCount: activePath != null ? (_argsByPath[activePath]?.length ?? 0) : 0,
        wordWrap: settings.wordWrap,
        onToggleWordWrap: () => settings.setWordWrap(!settings.wordWrap),
        onFontSizePressed: () => showFontSizeDialog(context, settings),
        onPreviewUiPressed: activeController != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UiPreviewScreen(source: activeController.text),
                  ),
                )
            : null,
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
  }
}

class _EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String fileName;
  final bool isDirty;
  final bool useSidebar;
  final bool isRunning;
  final VoidCallback? onRunPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback? onFindPressed;
  final VoidCallback? onGoToLinePressed;
  final VoidCallback? onArgumentsPressed;
  final int argsCount;
  final bool wordWrap;
  final VoidCallback onToggleWordWrap;
  final VoidCallback onFontSizePressed;
  final VoidCallback? onPreviewUiPressed;

  const _EditorAppBar({
    required this.fileName,
    required this.isDirty,
    required this.useSidebar,
    required this.isRunning,
    required this.onRunPressed,
    required this.onSavePressed,
    required this.onFindPressed,
    required this.onGoToLinePressed,
    required this.onArgumentsPressed,
    required this.argsCount,
    required this.wordWrap,
    required this.onToggleWordWrap,
    required this.onFontSizePressed,
    required this.onPreviewUiPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !useSidebar,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(fileName, overflow: TextOverflow.ellipsis),
          ),
          if (isDirty) ...[
            const SizedBox(width: AppConstants.spaceSm),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Find & Replace',
          icon: const Icon(Icons.search_rounded),
          onPressed: onFindPressed,
        ),
        IconButton(
          tooltip: 'Save',
          icon: const Icon(Icons.save_outlined),
          onPressed: onSavePressed,
        ),
        IconButton(
          tooltip: isRunning ? 'Stop' : 'Run',
          icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
          color: isRunning ? Theme.of(context).colorScheme.error : null,
          onPressed: onRunPressed,
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          enabled: onGoToLinePressed != null,
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: onGoToLinePressed,
              child: const ListTile(
                leading: Icon(Icons.arrow_forward_rounded),
                title: Text('Go to line'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: onFontSizePressed,
              child: const ListTile(
                leading: Icon(Icons.format_size_rounded),
                title: Text('Font size'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: onArgumentsPressed,
              child: ListTile(
                leading: const Icon(Icons.terminal_rounded),
                title: Text(argsCount > 0 ? 'Arguments ($argsCount)' : 'Arguments'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            CheckedPopupMenuItem<VoidCallback>(
              value: onToggleWordWrap,
              checked: wordWrap,
              padding: EdgeInsets.zero,
              child: const Text('Word wrap'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: onPreviewUiPressed,
              child: const ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Preview UI'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.appBarHeight);
}

class _EditorBody extends StatelessWidget {
  final CodeEditorController? controller;
  final UndoHistoryController? undoController;
  final double fontSize;
  final bool wordWrap;
  final bool showFindReplace;
  final VoidCallback onCloseFindReplace;

  const _EditorBody({
    required this.controller,
    required this.undoController,
    required this.fontSize,
    required this.wordWrap,
    required this.showFindReplace,
    required this.onCloseFindReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FileTabBar(),
        if (showFindReplace && controller != null)
          FindReplaceBar(
            // Keyed to the controller so switching files while Find is
            // open starts a fresh search session instead of showing
            // match highlights computed against a different file.
            key: ValueKey(controller),
            controller: controller!,
            onClose: onCloseFindReplace,
          ),
        Expanded(
          // Deliberately NOT keyed by the active file's path. Re-keying
          // forced a full remount on every tab switch, which reset the
          // visible cursor position to the start of the file — see
          // CodeEditor's doc comment. CodeEditor's own didUpdateWidget
          // handles the controller swap correctly on its own.
          child: controller != null
              ? CodeEditor(
                  controller: controller!,
                  undoController: undoController,
                  fontSize: fontSize,
                  wordWrap: wordWrap,
                )
              : const _NoFileOpenPlaceholder(),
        ),
        if (controller != null && undoController != null)
          CodingToolbar(controller: controller!, undoController: undoController!),
        const ConsolePanel(),
      ],
    );
  }
}

class _NoFileOpenPlaceholder extends StatelessWidget {
  const _NoFileOpenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Text(
          'No file open.\nCreate or pick one from the file tree.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
