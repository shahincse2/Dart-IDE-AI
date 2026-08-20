import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/themes.dart';
import 'code_editor_controller.dart';

class _ToolbarAction {
  final String label;
  final String insertText;
  /// How many characters from the end of [insertText] the cursor should
  /// land before. 0 = cursor after the whole insertion (the common
  /// case). For pairs like `{}` this is 1, so the cursor sits between
  /// the two characters.
  final int cursorOffsetFromEnd;
  /// If true and there's an active text selection, the action wraps the
  /// selection with the open/close halves of [insertText] instead of
  /// replacing it (Section 15).
  final bool wrapsSelection;

  const _ToolbarAction(
    this.label,
    this.insertText, {
    this.cursorOffsetFromEnd = 0,
    this.wrapsSelection = false,
  });
}

const List<_ToolbarAction> _actions = [
  _ToolbarAction('{ }', '{}', cursorOffsetFromEnd: 1, wrapsSelection: true),
  _ToolbarAction('( )', '()', cursorOffsetFromEnd: 1, wrapsSelection: true),
  _ToolbarAction('[ ]', '[]', cursorOffsetFromEnd: 1, wrapsSelection: true),
  _ToolbarAction(';', ';'),
  _ToolbarAction(':', ':'),
  _ToolbarAction('=', '='),
  _ToolbarAction('=>', '=>'),
  _ToolbarAction('.', '.'),
  _ToolbarAction(',', ','),
  _ToolbarAction("'", "''", cursorOffsetFromEnd: 1, wrapsSelection: true),
  _ToolbarAction('"', '""', cursorOffsetFromEnd: 1, wrapsSelection: true),
  _ToolbarAction('_', '_'),
  _ToolbarAction('??', '??'),
  _ToolbarAction('??=', '??='),
  _ToolbarAction('?.', '?.'),
  _ToolbarAction('==', '=='),
  _ToolbarAction('!=', '!='),
  _ToolbarAction('&&', '&&'),
  _ToolbarAction('||', '||'),
  _ToolbarAction('Tab', '  '),
];

/// One-tap access to characters that are slow to reach on a mobile
/// keyboard (Section 13–16). A horizontally scrollable single row is
/// the simplest predictable layout for Phase 2; categorized/expandable
/// grouping can be layered on in Phase 7 if the character set grows.
class CodingToolbar extends StatelessWidget {
  final CodeEditorController controller;

  const CodingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = controller.scheme;
    return ColoredBox(
      color: scheme.gutterBackground,
      child: SizedBox(
        height: AppConstants.codingToolbarHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
          itemCount: _actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spaceXs),
          itemBuilder: (context, index) => _ToolbarChip(
            action: _actions[index],
            controller: controller,
            scheme: scheme,
          ),
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final _ToolbarAction action;
  final CodeEditorController controller;
  final EditorColorScheme scheme;

  const _ToolbarChip({
    required this.action,
    required this.controller,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _apply,
        child: Container(
          constraints: const BoxConstraints(minWidth: AppConstants.compactTouchTarget),
          height: AppConstants.compactTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
          alignment: Alignment.center,
          child: Text(
            action.label,
            style: TextStyle(
              fontFamily: editorFontFamily,
              fontSize: 14,
              color: scheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _apply() {
    final value = controller.value;
    final selection = value.selection;
    final text = value.text;

    if (action.wrapsSelection && selection.isValid && !selection.isCollapsed) {
      final selected = text.substring(selection.start, selection.end);
      final splitAt = action.insertText.length - action.cursorOffsetFromEnd;
      final open = action.insertText.substring(0, splitAt);
      final close = action.insertText.substring(splitAt);
      final newText = text.replaceRange(selection.start, selection.end, '$open$selected$close');
      final newCursor = selection.start + open.length + selected.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
      return;
    }

    final insertAt = selection.isValid ? selection.start : text.length;
    final removeEnd = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(insertAt, removeEnd, action.insertText);
    final newCursor = insertAt + action.insertText.length - action.cursorOffsetFromEnd;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
