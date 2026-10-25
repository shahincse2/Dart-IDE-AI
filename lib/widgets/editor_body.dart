import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'code_editor.dart';
import 'code_editor_controller.dart';
import 'coding_toolbar.dart';
import 'completion_model.dart';
import 'completion_overlay.dart';
import 'console_panel.dart';
import 'file_tab_bar.dart';
import 'find_replace_bar.dart';
import 'measure_size.dart';

/// The least height the editor itself keeps when the console is made tall.
const double kMinEditorHeight = 100;

/// What the editor screen shows under its app bar: the tabs, the find bar,
/// the editor, the completion/coding toolbars and the console.
///
/// It measures the tabs and toolbars, so the console is told how much room
/// is really left for it. Whatever the other parts need, and whether the
/// keyboard is up, the console never pushes them off the screen.
class EditorBody extends StatefulWidget {
  final CodeEditorController? controller;
  final UndoHistoryController? undoController;
  final double fontSize;
  final bool wordWrap;
  final bool showFindReplace;
  final bool findReplaceExpanded;
  final VoidCallback onCloseFindReplace;

  const EditorBody({
    super.key,
    required this.controller,
    required this.undoController,
    required this.fontSize,
    required this.wordWrap,
    required this.showFindReplace,
    required this.findReplaceExpanded,
    required this.onCloseFindReplace,
  });

  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
  // Guesses for the very first frame, until the real sizes are measured.
  double _topHeight = 48;
  double _bottomHeight = 140;

  /// The completions of the file being edited: one model per editor
  /// controller, shared by the suggestion bar and the Tab key.
  CompletionModel? _completion;

  void _measuredTop(Size size) {
    if (mounted && (size.height - _topHeight).abs() > 0.5) {
      setState(() => _topHeight = size.height);
    }
  }

  void _measuredBottom(Size size) {
    if (mounted && (size.height - _bottomHeight).abs() > 0.5) {
      setState(() => _bottomHeight = size.height);
    }
  }

  CompletionModel? _completionFor(CodeEditorController? controller) {
    final current = _completion;
    if (controller == null) {
      current?.dispose();
      return _completion = null;
    }
    if (current != null && identical(current.controller, controller)) {
      return current;
    }
    current?.dispose();
    return _completion = CompletionModel(controller);
  }

  @override
  void dispose() {
    _completion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final undoController = widget.undoController;
    final hasToolbars = controller != null && undoController != null;
    final completion = _completionFor(controller);
    completion?.indentSize =
        context.select<SettingsProvider, int>((s) => s.indentSize);

    return LayoutBuilder(
      builder: (context, box) {
        final others = _topHeight + (hasToolbars ? _bottomHeight : 0);
        final room = box.maxHeight - others - kMinEditorHeight;

        return Column(
          children: [
            MeasureSize(
              onChange: _measuredTop,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FileTabBar(),
                  if (widget.showFindReplace && controller != null)
                    FindReplaceBar(
                      key: ValueKey(controller),
                      controller: controller,
                      onClose: widget.onCloseFindReplace,
                      initiallyExpanded: widget.findReplaceExpanded,
                    ),
                ],
              ),
            ),
            Expanded(
              child: controller != null
                  // Key presses reach this Focus on their way up from the
                  // editor's text field: Tab goes to the completions first.
                  ? Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: (_, event) => completion!.handleKey(event),
                      child: CodeEditor(
                        controller: controller,
                        undoController: undoController,
                        fontSize: widget.fontSize,
                        wordWrap: widget.wordWrap,
                      ),
                    )
                  : const _NoFileOpenPlaceholder(),
            ),
            if (hasToolbars)
              MeasureSize(
                onChange: _measuredBottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CompletionOverlay(model: completion!),
                    CodingToolbar(
                      controller: controller,
                      undoController: undoController,
                    ),
                  ],
                ),
              ),
            ConsolePanel(roomHeight: room),
          ],
        );
      },
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
