import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/console_event.dart';
import '../providers/file_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_share_service.dart';
import '../services/print_service.dart';
import '../utils/constants.dart';
import '../utils/runner_error_parser.dart';
import '../utils/themes.dart';
import '../widgets/arguments_dialog.dart';
import '../widgets/code_editor.dart';
import '../widgets/code_editor_controller.dart';
import '../widgets/coding_toolbar.dart';
import '../widgets/completion_overlay.dart';
import '../widgets/console_panel.dart';
import '../widgets/file_tab_bar.dart';
import '../widgets/file_tree.dart';
import '../widgets/find_replace_bar.dart';
import '../widgets/font_size_dialog.dart';
import '../widgets/go_to_line_dialog.dart';
import '../widgets/variable_inspector_panel.dart';
import 'settings_screen.dart';
import 'ui_preview_screen.dart';

/// The main workspace. This screen owns the responsive shell described
/// in Section 44:
///   - Portrait: drawer for file navigation, editor fills the rest.
///   - Landscape / tablet: persistent sidebar beside the editor.
///
/// What's real as of Phase 10: a Settings entry point (app bar's
/// overflow menu) into the real Settings screen — themes, font size,
/// indent size, word wrap, auto save — plus Bluetooth/physical-
/// keyboard shortcuts (Section 43): Ctrl+S save, Ctrl+Enter run/stop,
/// Ctrl+F find, Ctrl+H find & replace, Ctrl+G go to line. Ctrl+Z/
/// Ctrl+Shift+Z aren't bound here deliberately — Flutter's TextField
/// already handles both natively via the `undoController` wired up in
/// Phase 7. Plus everything from Phases 2-9: real multi-file tabs,
/// live Dart execution with genuine Isolate-based Stop/timeout, the
/// real Console panel, Find & Replace, Go to line, Undo/Redo,
/// arguments, best-effort error-line highlighting, and UI Preview via
/// tom_d4rt_flutter. Honest gaps carried forward: interactive stdin
/// (no confirmed API), and UI Preview has no Isolate-based Stop
/// (Widgets can't cross an Isolate boundary).
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
  final FileShareService _fileShareService = FileShareService();
  final PrintService _printService = PrintService();

  bool _showFindReplace = false;
  bool _findReplaceExpanded = false;
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
  /// guaranteed to always find one (confirmed: it won't, for runtime
  /// exceptions — only a real chance for syntax/parse errors).
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

  Future<void> _handleExport() async {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null || activePath == null) return;
    final fileName = activePath.split('/').last;
    await _fileShareService.exportDartFile(
      content: activeController.text,
      fileName: fileName,
    );
  }

  Future<void> _handleImport() async {
    final result = await _fileShareService.importDartFile();
    if (result == null || !mounted) return;
    final project = _fileProvider.currentProject;
    if (project == null) return;
    await _fileProvider.createFile('', result.name.replaceAll('.dart', ''));
    // Wait for the new file to be opened as the active tab,
    // then write the imported content into its controller.
    await Future.delayed(const Duration(milliseconds: 300));
    final activePath = _fileProvider.activeTab;
    if (activePath != null && mounted) {
      _controllers[activePath]?.value = TextEditingValue(
        text: result.content,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _fileProvider.scheduleAutoSave(activePath, result.content);
    }
  }

  Future<void> _handleShareCode() async {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null || activePath == null) return;

    final fileName = activePath.split('/').last;

    // await করার আগেই context ক্যাপচার
    final messenger = ScaffoldMessenger.of(context);

    final result = await SharePlus.instance.share(
      ShareParams(text: activeController.text, subject: fileName),
    );

    if (!mounted) return;

    if (result.status == ShareResultStatus.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('"$fileName" shared successfully')),
      );
    } else if (result.status == ShareResultStatus.dismissed) {
      messenger.showSnackBar(const SnackBar(content: Text('Share cancelled')));
    } else if (result.status == ShareResultStatus.unavailable) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app available to share')),
      );
    }
  }

  Future<void> _handlePrint() async {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null || activePath == null) return;
    await _printService.printCode(
      source: activeController.text,
      fileName: activePath.split('/').last,
    );
  }

  Future<void> _handleSharePdf() async {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null || activePath == null) return;
    await _printService.sharePdf(
      source: activeController.text,
      fileName: activePath.split('/').last,
    );
  }

  /// Keeps [_controllers] matched to [FileProvider.openTabs]: disposes
  /// controllers for tabs that closed, and creates + loads one for any
  /// newly opened tab.
  Future<void> _syncControllers() async {
    final openTabs = _fileProvider.openTabs;

    final toRemove =
        _controllers.keys.where((path) => !openTabs.contains(path)).toList();
    for (final path in toRemove) {
      _controllers.remove(path)?.dispose();
      _undoControllers.remove(path)?.dispose();
      _argsByPath.remove(path);
    }

    for (final path in openTabs) {
      if (_controllers.containsKey(path) || _loadingPaths.contains(path)) {
        continue;
      }
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
      controller.addListener(
        () => _fileProvider.scheduleAutoSave(path, controller.text),
      );

      _controllers[path] = controller;
      _undoControllers[path] = UndoHistoryController();
      _loadingPaths.remove(path);
      if (mounted) setState(() {});
    }
  }

  // ---- Shared action handlers — used by both the app bar buttons and
  // the keyboard shortcuts below (Section 43), so there's exactly one
  // place each action is implemented. ----

  void _handleRunOrStop() {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null) return;
    if (_runnerProvider.isRunning) {
      _runnerProvider.stop();
    } else {
      activeController.setErrorLine(null);
      _lastRunPath = activePath;
      _lastSeenRunnerEventCount = 0;
      _runnerProvider.run(
        activeController.text,
        args: _argsByPath[activePath] ?? const [],
      );
    }
  }

  void _handleSave() {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null || activePath == null) return;
    _fileProvider.saveNow(activePath, activeController.text);
  }

  /// Ctrl+F / Ctrl+H (Section 43): unlike the app bar's search icon
  /// (a toggle), a keyboard shortcut should *open* Find — pressing it
  /// again while already open shouldn't close the bar out from under
  /// someone still typing a query.
  void _handleOpenFind({required bool expandReplace}) {
    if (_fileProvider.activeTab == null) return;
    setState(() {
      _showFindReplace = true;
      _findReplaceExpanded = expandReplace;
    });
  }

  void _handleGoToLine() {
    final activePath = _fileProvider.activeTab;
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    if (activeController == null) return;
    showGoToLineDialog(context, activeController);
  }

  void _handleFoldAll() {
    final path = _fileProvider.activeTab;
    if (path == null) return;
    _controllers[path]?.foldAll();
  }

  void _handleUnfoldAll() {
    final path = _fileProvider.activeTab;
    if (path == null) return;
    _controllers[path]?.unfoldAll();
  }

  void _handleInspect() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VariableInspectorPanel(),
    );
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
    final activeController =
        activePath != null ? _controllers[activePath] : null;
    final activeUndoController =
        activePath != null ? _undoControllers[activePath] : null;

    final isTablet = AppConstants.isTablet(context);
    final isLandscape = AppConstants.isLandscape(context);
    final useSidebar = isTablet || isLandscape;

    final editorArea = _EditorBody(
      controller: activeController,
      undoController: activeUndoController,
      fontSize: settings.editorFontSize,
      wordWrap: settings.wordWrap,
      showFindReplace: _showFindReplace && activeController != null,
      findReplaceExpanded: _findReplaceExpanded,
      onCloseFindReplace: () => setState(() => _showFindReplace = false),
    );

    final scaffold = Scaffold(
      appBar: _EditorAppBar(
        onShareCodePressed: activeController != null ? _handleShareCode : null,
        onExportPressed: activeController != null ? _handleExport : null,
        onPrintPressed: activeController != null ? _handlePrint : null,
        onSharePdfPressed: activeController != null ? _handleSharePdf : null,
        onImportPressed: _handleImport,
        fileName: fileProvider.activeFileName ?? 'No file open',
        isDirty: activePath != null && fileProvider.isDirty(activePath),
        useSidebar: useSidebar,
        isRunning: runner.isRunning,
        onRunPressed: activeController == null ? null : _handleRunOrStop,
        onSavePressed: activeController != null ? _handleSave : null,
        onFindPressed: activeController != null
            ? () => setState(() {
                  if (_showFindReplace) {
                    _showFindReplace = false;
                  } else {
                    _showFindReplace = true;
                    _findReplaceExpanded = false;
                  }
                })
            : null,
        onGoToLinePressed: activeController != null ? _handleGoToLine : null,
        onFoldAllPressed: activeController != null ? _handleFoldAll : null,
        onUnfoldAllPressed: activeController != null ? _handleUnfoldAll : null,
        onArgumentsPressed: activeController != null
            ? () async {
                final current = _argsByPath[activePath]?.join(' ') ?? '';
                final result = await showArgumentsDialog(context, current);
                if (result != null) {
                  setState(() => _argsByPath[activePath!] = result);
                }
              }
            : null,
        argsCount:
            activePath != null ? (_argsByPath[activePath]?.length ?? 0) : 0,
        wordWrap: settings.wordWrap,
        onToggleWordWrap: () => settings.setWordWrap(!settings.wordWrap),
        onFontSizePressed: () => showFontSizeDialog(context, settings),
        onPreviewUiPressed: activeController != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UiPreviewScreen(source: activeController.text),
                  ),
                )
            : null,
        onInspectPressed: _handleInspect,
        onSettingsPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
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

    // Section 43's Bluetooth/physical-keyboard shortcuts. Ctrl+Z /
    // Ctrl+Shift+Z are deliberately NOT bound here — Flutter's
    // TextField already handles both natively once given an
    // `undoController` (Phase 7), so adding our own binding would be
    // redundant at best and could double-fire at worst.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSave,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _handleRunOrStop,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _handleOpenFind(expandReplace: false),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            _handleOpenFind(expandReplace: true),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true):
            _handleGoToLine,
      },
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
  final VoidCallback? onFoldAllPressed;
  final VoidCallback? onUnfoldAllPressed;
  final VoidCallback? onArgumentsPressed;
  final int argsCount;
  final bool wordWrap;
  final VoidCallback onToggleWordWrap;
  final VoidCallback onFontSizePressed;
  final VoidCallback? onPreviewUiPressed;
  final VoidCallback onInspectPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback? onExportPressed;
  final VoidCallback? onImportPressed;
  final VoidCallback? onShareCodePressed;
  final VoidCallback? onPrintPressed;
  final VoidCallback? onSharePdfPressed;

  const _EditorAppBar({
    required this.fileName,
    required this.isDirty,
    required this.useSidebar,
    required this.isRunning,
    required this.onRunPressed,
    required this.onSavePressed,
    required this.onFindPressed,
    required this.onGoToLinePressed,
    required this.onFoldAllPressed,
    required this.onUnfoldAllPressed,
    required this.onArgumentsPressed,
    required this.argsCount,
    required this.wordWrap,
    required this.onToggleWordWrap,
    required this.onFontSizePressed,
    required this.onPreviewUiPressed,
    required this.onInspectPressed,
    required this.onSettingsPressed,
    required this.onExportPressed,
    required this.onImportPressed,
    required this.onShareCodePressed,
    required this.onPrintPressed,
    required this.onSharePdfPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !useSidebar,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis)),
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
          tooltip: isDirty ? 'Save (unsaved changes)' : 'Save',
          icon: Icon(
            Icons.save_outlined,
            color: isDirty
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
          onPressed: isDirty ? onSavePressed : null,
        ),
        IconButton(
          tooltip: isRunning ? 'Stop' : 'Run',
          icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
          color: isRunning ? Theme.of(context).colorScheme.error : null,
          onPressed: onRunPressed,
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: onGoToLinePressed != null,
              value: onGoToLinePressed,
              child: const ListTile(
                leading: Icon(Icons.arrow_forward_rounded),
                title: Text('Go to line'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: onFoldAllPressed != null,
              value: onFoldAllPressed,
              child: const ListTile(
                leading: Icon(Icons.unfold_less_rounded),
                title: Text('Fold all'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: onUnfoldAllPressed != null,
              value: onUnfoldAllPressed,
              child: const ListTile(
                leading: Icon(Icons.unfold_more_rounded),
                title: Text('Unfold all'),
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
              enabled: onArgumentsPressed != null,
              value: onArgumentsPressed,
              child: ListTile(
                leading: const Icon(Icons.terminal_rounded),
                title: Text(
                  argsCount > 0 ? 'Arguments ($argsCount)' : 'Arguments',
                ),
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
              enabled: onExportPressed != null,
              value: onExportPressed,
              child: const ListTile(
                leading: Icon(Icons.upload_file_outlined),
                title: Text('Export file'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: onImportPressed,
              child: const ListTile(
                leading: Icon(Icons.download_for_offline_outlined),
                title: Text('Import file'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: onShareCodePressed != null,
              value: onShareCodePressed,
              child: const ListTile(
                leading: Icon(Icons.share_outlined),
                title: Text('Share code'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: onPrintPressed != null,
              value: onPrintPressed,
              child: const ListTile(
                leading: Icon(Icons.print_outlined),
                title: Text('Print'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: onSharePdfPressed != null,
              value: onSharePdfPressed,
              child: const ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('Share as PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: onPreviewUiPressed != null,
              value: onPreviewUiPressed,
              child: const ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Preview UI'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: onInspectPressed,
              child: const ListTile(
                leading: Icon(Icons.manage_search_rounded),
                title: Text('Inspect variables'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: onSettingsPressed,
              child: const ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
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
  final bool findReplaceExpanded;
  final VoidCallback onCloseFindReplace;

  const _EditorBody({
    required this.controller,
    required this.undoController,
    required this.fontSize,
    required this.wordWrap,
    required this.showFindReplace,
    required this.findReplaceExpanded,
    required this.onCloseFindReplace,
  });

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final undoController = this.undoController;

    return Column(
      children: [
        const FileTabBar(),
        if (showFindReplace && controller != null)
          FindReplaceBar(
            key: ValueKey(controller),
            controller: controller,
            onClose: onCloseFindReplace,
            initiallyExpanded: findReplaceExpanded,
          ),
        Expanded(
          child: controller != null
              ? CodeEditor(
                  controller: controller,
                  undoController: undoController,
                  fontSize: fontSize,
                  wordWrap: wordWrap,
                )
              : const _NoFileOpenPlaceholder(),
        ),
        if (controller != null && undoController != null) ...[
          CompletionOverlay(controller: controller),
          CodingToolbar(
            controller: controller,
            undoController: undoController,
          ),
        ],
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
