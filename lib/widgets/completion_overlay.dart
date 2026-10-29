import 'package:flutter/material.dart';

import '../utils/completion_engine.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import 'completion_model.dart';

/// Inline code completion bar shown between the editor and the coding
/// toolbar. Hidden when there are no suggestions or the cursor is not in a
/// word. The chosen suggestion has an outline: it is the one Tab inserts
/// (Down and Up choose another).
class CompletionOverlay extends StatefulWidget {
  final CompletionModel model;

  const CompletionOverlay({super.key, required this.model});

  /// Tall enough to be tapped with a finger.
  static const double barHeight = 44;

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay> {
  final List<GlobalKey> _chipKeys = [];
  List<CompletionItem>? _shownList;
  int _shownSelection = 0;

  GlobalKey _keyFor(int index) {
    while (_chipKeys.length <= index) {
      _chipKeys.add(GlobalKey());
    }
    return _chipKeys[index];
  }

  /// Scrolls the bar so the chosen chip is in view: after choosing another
  /// one, and back to the first when the suggestions change.
  void _keepChosenInView() {
    final model = widget.model;
    final changed = !identical(_shownList, model.suggestions);
    if (!changed && _shownSelection == model.selectedIndex) return;
    _shownList = model.suggestions;
    _shownSelection = model.selectedIndex;
    final index = model.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _keyFor(index).currentContext;
      if (chip == null || !chip.mounted) return;
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: AppConstants.animFast,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      // The controller too: a theme change must repaint the bar.
      listenable: Listenable.merge([model, model.controller]),
      builder: (context, _) {
        final suggestions = model.suggestions;
        if (suggestions.isEmpty) return const SizedBox.shrink();
        _keepChosenInView();

        final scheme = model.controller.scheme;
        return Container(
          height: CompletionOverlay.barHeight,
          color: scheme.gutterBackground,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => VerticalDivider(
              width: 1,
              color: scheme.gutterText.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, i) => _SuggestionChip(
              key: _keyFor(i),
              item: suggestions[i],
              scheme: scheme,
              isChosen: i == model.selectedIndex,
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
  final bool isChosen;
  final VoidCallback onTap;

  const _SuggestionChip({
    super.key,
    required this.item,
    required this.scheme,
    required this.isChosen,
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
      selected: isChosen,
      label: 'Insert ${item.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
          // The outline (a shape, not only a colour) marks what Tab inserts.
          decoration: isChosen
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
