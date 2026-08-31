import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import '../widgets/code_editor.dart';
import '../widgets/code_editor_controller.dart';
import '../widgets/coding_toolbar.dart';
import '../widgets/console_panel.dart';
import '../widgets/file_tab_bar.dart';
import '../widgets/file_tree.dart';

/// The main workspace. This screen owns the responsive shell described
/// in Section 44:
///   - Portrait: drawer for file navigation, editor fills the rest.
///   - Landscape / tablet: persistent sidebar beside the editor.
///
/// What's real as of Phase 6: real multi-file tabs. Each open tab gets
/// its own [CodeEditorController] (kept alive in [_controllers] for as
/// long as the tab stays open), so switching tabs doesn't lose cursor
/// position or undo history the way Phase 5's single-controller swap
/// did. Still placeholders: interactive stdin / argument entry (Phase 8).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final FileProvider _fileProvider;
  final Map<String, CodeEditorController> _controllers = {};
  final Set<String> _loadingPaths = {};

  @override
  void initState() {
    super.initState();
    _fileProvider = context.read<FileProvider>();
    _fileProvider.addListener(_onFileProviderChanged);
    _syncControllers();
  }

  void _onFileProviderChanged() => _syncControllers();

  /// Keeps [_controllers] matched to [FileProvider.openTabs]: disposes
  /// controllers for tabs that closed, and creates + loads one for any
  /// newly opened tab.
  Future<void> _syncControllers() async {
    final openTabs = _fileProvider.openTabs;

    final toRemove = _controllers.keys.where((path) => !openTabs.contains(path)).toList();
    for (final path in toRemove) {
      _controllers.remove(path)?.dispose();
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
      _loadingPaths.remove(path);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _fileProvider.removeListener(_onFileProviderChanged);
    _fileProvider.flushAllPendingSaves();
    for (final controller in _controllers.values) {
      controller.dispose();
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

    final isTablet = AppConstants.isTablet(context);
    final isLandscape = AppConstants.isLandscape(context);
    final useSidebar = isTablet || isLandscape;

    final editorArea = _EditorBody(
      activePath: activePath,
      controller: activeController,
      fontSize: settings.editorFontSize,
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
                  runner.run(activeController.text);
                }
              },
        onSavePressed: activeController != null
            ? () => fileProvider.saveNow(activePath!, activeController.text)
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

  const _EditorAppBar({
    required this.fileName,
    required this.isDirty,
    required this.useSidebar,
    required this.isRunning,
    required this.onRunPressed,
    required this.onSavePressed,
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
        IconButton(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: null,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.appBarHeight);
}

class _EditorBody extends StatelessWidget {
  final String? activePath;
  final CodeEditorController? controller;
  final double fontSize;

  const _EditorBody({
    required this.activePath,
    required this.controller,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FileTabBar(),
        Expanded(
          child: controller != null
              // Keyed by path so switching tabs gives each file its own
              // fresh scroll position rather than inheriting whatever
              // the previous tab's viewport happened to be at — cursor
              // position and undo history still carry over correctly
              // since those live on the controller, not this widget.
              ? CodeEditor(
                  key: ValueKey(activePath),
                  controller: controller!,
                  fontSize: fontSize,
                )
              : const _NoFileOpenPlaceholder(),
        ),
        if (controller != null) CodingToolbar(controller: controller!),
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
