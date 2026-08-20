import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
/// What's real as of Phase 2: syntax-highlighted editing, synced line
/// numbers, current-line highlight, bracket matching, auto-indent, and
/// the coding toolbar. Still placeholders: multi-file tabs (Phase 6),
/// the console (Phase 4), and Save/Run (Phase 5 / Phase 3) — each
/// arrives in its own phase rather than being faked here.
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
    _controller.scheme = editorSchemeFromName(settings.editorThemeName);
    _controller.indentSize = settings.indentSize;

    final isTablet = AppConstants.isTablet(context);
    final isLandscape = AppConstants.isLandscape(context);
    final useSidebar = isTablet || isLandscape;

    final editorArea = _EditorBody(
      controller: _controller,
      fontSize: settings.editorFontSize,
    );

    return Scaffold(
      appBar: _EditorAppBar(isDirty: _isDirty, useSidebar: useSidebar),
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

  const _EditorAppBar({required this.isDirty, required this.useSidebar});

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
          tooltip: 'Run',
          icon: const Icon(Icons.play_arrow_rounded),
          // Real execution lands with DartRunner in Phase 3.
          onPressed: null,
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

  const _EditorBody({required this.controller, required this.fontSize});

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
        // Console panel mounts here in Phase 4.
      ],
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
