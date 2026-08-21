import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/console_event.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import '../widgets/code_editor.dart';
import '../widgets/code_editor_controller.dart';
import '../widgets/coding_toolbar.dart';

/// The main workspace. This screen owns the responsive shell described
/// in Section 44:
///   - Portrait: drawer for file navigation, editor fills the rest.
///   - Landscape / tablet: persistent sidebar beside the editor.
///
/// What's real as of Phase 3: syntax-highlighted editing with synced
/// line numbers/current-line/bracket-matching/auto-indent (Phase 2),
/// plus actual Dart execution via DartRunnerService — Run/Stop are
/// live, with genuine Isolate-based cancellation and a real 10s
/// timeout. Still placeholders: multi-file tabs (Phase 6), the real
/// animated Console panel (Phase 4 — a plain temporary output list
/// stands in for it now), and Save (Phase 5).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final CodeEditorController _controller;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = CodeEditorController(
      scheme: editorSchemeFromName(settings.editorThemeName),
      indentSize: settings.indentSize,
      text: "void main() {\n  print('Hello, Dart!');\n}\n",
    );
    _controller.addListener(_onEdited);
  }

  void _onEdited() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onEdited);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller's rendering options in sync with live
    // settings changes (e.g. flipping the editor theme or indent size
    // in Settings, once that screen exists in Phase 10) without
    // recreating the controller — recreating it would lose undo
    // history and cursor position.
    final settings = context.watch<SettingsProvider>();
    final runner = context.watch<RunnerProvider>();
    _controller.scheme = editorSchemeFromName(settings.editorThemeName);
    _controller.indentSize = settings.indentSize;

    final isTablet = AppConstants.isTablet(context);
    final isLandscape = AppConstants.isLandscape(context);
    final useSidebar = isTablet || isLandscape;

    final editorArea = _EditorBody(
      controller: _controller,
      fontSize: settings.editorFontSize,
      runner: runner,
    );

    return Scaffold(
      appBar: _EditorAppBar(
        isDirty: _isDirty,
        useSidebar: useSidebar,
        isRunning: runner.isRunning,
        onRunPressed: () {
          if (runner.isRunning) {
            runner.stop();
          } else {
            runner.run(_controller.text);
          }
        },
      ),
      drawer: useSidebar ? null : const _FileDrawer(),
      body: SafeArea(
        child: useSidebar
            ? Row(
                children: [
                  const SizedBox(
                    width: 240,
                    child: _FileDrawer(embedded: true),
                  ),
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
  final bool isDirty;
  final bool useSidebar;
  final bool isRunning;
  final VoidCallback onRunPressed;

  const _EditorAppBar({
    required this.isDirty,
    required this.useSidebar,
    required this.isRunning,
    required this.onRunPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !useSidebar,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text(
              'main.dart',
              overflow: TextOverflow.ellipsis,
            ),
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
          // Real save lands with FileProvider in Phase 5.
          onPressed: null,
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
  final CodeEditorController controller;
  final double fontSize;
  final RunnerProvider runner;

  const _EditorBody({
    required this.controller,
    required this.fontSize,
    required this.runner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar placeholder — becomes a real scrollable multi-file
        // tab strip in Phase 6.
        Container(
          height: AppConstants.tabBarHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            'main.dart',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: CodeEditor(controller: controller, fontSize: fontSize),
        ),
        CodingToolbar(controller: controller),
        if (runner.events.isNotEmpty || runner.isRunning) _TempOutputPanel(runner: runner),
      ],
    );
  }
}

/// A deliberately plain stand-in for the real Console panel (Phase 4:
/// hidden-by-default animated bottom sheet, drag-resize, copy/clear/
/// save). This exists only so Phase 3's execution is actually visible
/// and testable — it reads the exact same [RunnerProvider.events] the
/// real panel will.
class _TempOutputPanel extends StatelessWidget {
  final RunnerProvider runner;

  const _TempOutputPanel({required this.runner});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceMd,
              vertical: AppConstants.spaceSm,
            ),
            child: Row(
              children: [
                Text('Output (temporary — Phase 4 replaces this)',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                if (runner.isRunning)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
              itemCount: runner.events.length,
              itemBuilder: (context, i) {
                final e = runner.events[i];
                final isError = e.type == ConsoleEventType.stderr;
                final label = e.type == ConsoleEventType.exitCode
                    ? 'Program finished (exit code ${e.exitCode})'
                    : (e.text ?? '');
                return Text(
                  label,
                  style: TextStyle(
                    fontFamily: editorFontFamily,
                    fontSize: 12,
                    color: isError ? scheme.error : scheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FileDrawer extends StatelessWidget {
  final bool embedded;

  const _FileDrawer({this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceMd),
                child: Text(
                  'File tree arrives in Phase 5.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return embedded ? content : Drawer(child: content);
  }
}
