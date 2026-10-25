import 'package:flutter/material.dart';

import '../utils/completion_engine.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import 'completion_model.dart';

/// Inline code completion bar shown between the editor and the coding
/// toolbar. Hidden when there are no suggestions or the cursor is not in a
/// word. The first suggestion has an outline: it is the one Tab inserts.
class CompletionOverlay extends StatelessWidget {
  final CompletionModel model;

  const CompletionOverlay({super.key, required this.model});

  /// Tall enough to be tapped with a finger.
  static const double barHeight = 44;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // The controller too: a theme change must repaint the bar.
      listenable: Listenable.merge([model, model.controller]),
      builder: (context, _) {
        final suggestions = model.suggestions;
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final scheme = model.controller.scheme;
        return Container(
          height: barHeight,
          color: scheme.gutterBackground,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => VerticalDivider(
              width: 1,
              color: scheme.gutterText.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, i) => _SuggestionChip(
              item: suggestions[i],
              scheme: scheme,
              isFirst: i == 0,
              onTap: () => model.accept(suggestions[i]),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final CompletionItem item;
  final EditorColorScheme scheme;
  final bool isFirst;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.item,
    required this.scheme,
    required this.isFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (item.kind) {
      CompletionKind.keyword => scheme.keyword,
      CompletionKind.snippet => scheme.function,
      CompletionKind.identifier => scheme.variable,
    };

    return Semantics(
      button: true,
      label: 'Insert ${item.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
          // The outline (a shape, not only a colour) marks what Tab inserts.
          decoration: isFirst
              ? BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
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
      ),
    );
  }
}
