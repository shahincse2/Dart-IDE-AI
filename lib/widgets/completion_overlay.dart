import 'package:flutter/material.dart';

import '../utils/completion_engine.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import 'code_editor_controller.dart';

/// Inline code completion bar shown between the editor and the coding
/// toolbar. Updates on every keystroke; hidden when there are no
/// suggestions or the cursor is not in a word.
class CompletionOverlay extends StatefulWidget {
  final CodeEditorController controller;

  const CompletionOverlay({super.key, required this.controller});

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay> {
  List<CompletionItem> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant CompletionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final offset = widget.controller.selection.baseOffset;
    if (offset < 0) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    final prefix = CompletionEngine.currentPrefix(
      widget.controller.text,
      offset,
    );
    final suggestions = CompletionEngine.suggest(
      prefix,
      widget.controller.text,
    );
    if (suggestions.length != _suggestions.length ||
        suggestions.map((e) => e.label).join() !=
            _suggestions.map((e) => e.label).join()) {
      setState(() => _suggestions = suggestions);
    }
  }

  void _apply(CompletionItem item) {
    final offset = widget.controller.selection.baseOffset;
    if (offset < 0) return;
    final prefix = CompletionEngine.currentPrefix(
      widget.controller.text,
      offset,
    );
    final text = widget.controller.text;
    final start = offset - prefix.length;
    final newText = text.replaceRange(start, offset, item.insertText);
    final newOffset = start + item.insertText.length;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    final scheme = widget.controller.scheme;
    return Container(
      height: 36,
      color: scheme.gutterBackground,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            VerticalDivider(width: 1, color: scheme.gutterText.withValues(alpha: 0.2)),
        itemBuilder: (context, i) {
          final item = _suggestions[i];
          return _SuggestionChip(
            item: item,
            scheme: scheme,
            onTap: () => _apply(item),
          );
        },
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final CompletionItem item;
  final EditorColorScheme scheme;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.item,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (item.kind) {
      CompletionKind.keyword => scheme.keyword,
      CompletionKind.snippet => scheme.function,
      CompletionKind.identifier => scheme.variable,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.kind == CompletionKind.snippet
                  ? Icons.code_rounded
                  : Icons.text_fields_rounded,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: editorFontFamily,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
