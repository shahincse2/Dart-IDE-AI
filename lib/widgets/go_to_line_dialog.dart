import 'package:flutter/material.dart';

import 'code_editor_controller.dart';

/// Section 7's "go to line". Reuses the auto-scroll-to-cursor behavior
/// CodeEditor already has for Find & Replace navigation — moving the
/// selection here is enough to bring the target line into view too.
Future<void> showGoToLineDialog(BuildContext context, CodeEditorController controller) async {
  final lineCount = '\n'.allMatches(controller.text).length + 1;
  final textController = TextEditingController();

  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Go to line'),
      content: TextField(
        controller: textController,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: '1–$lineCount'),
        onSubmitted: (value) {
          final line = int.tryParse(value);
          if (line != null) Navigator.pop(dialogContext, line);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, int.tryParse(textController.text)),
          child: const Text('Go'),
        ),
      ],
    ),
  );

  if (result == null) return;
  final targetLine = result.clamp(1, lineCount);
  final offset = _offsetForLine(controller.text, targetLine);
  controller.selection = TextSelection.collapsed(offset: offset);
}

int _offsetForLine(String text, int lineNumber) {
  final lines = text.split('\n');
  final targetIndex = (lineNumber - 1).clamp(0, lines.length - 1);
  var offset = 0;
  for (var i = 0; i < targetIndex; i++) {
    offset += lines[i].length + 1; // +1 for the '\n' that split() consumed
  }
  return offset;
}
