import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../utils/completion_engine.dart';
import '../utils/snippet_session.dart';
import '../utils/snippet_template.dart';
import '../utils/text_edit.dart';
import 'code_editor_controller.dart';
import 'completion_keys.dart';

/// What is suggested for the word at the cursor, and what accepting a
/// suggestion does: the text is inserted (a snippet is lined up with the line
/// it goes into), the cursor lands on the snippet's first stop, and Tab walks
/// through the other stops. The keys are in [CompletionKeys].
class CompletionModel extends ChangeNotifier {
  CompletionModel(this.controller) : _lastText = controller.text {
    controller.addListener(_onControllerChanged);
    _refresh();
  }

  final CodeEditorController controller;

  /// Spaces per indentation level for inserted snippets.
  int indentSize = 2;

  late final CompletionKeys _keys = CompletionKeys(this);
  List<CompletionItem> _suggestions = const [];
  int _selected = 0;
  bool _dismissed = false;
  SnippetSession? _session;
  String _lastText;

  List<CompletionItem> get suggestions => _suggestions;
  bool get hasSuggestions => _suggestions.isNotEmpty;

  /// Which suggestion Tab would insert (0 for the first).
  int get selectedIndex => _selected;

  /// Gives a key press to the completions: handled, or ignored.
  KeyEventResult handleKey(KeyEvent event) => _keys.handle(event);

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = controller.text;
    if (text != _lastText) {
      _session = _session?.followEdit(TextEdit.between(_lastText, text));
      _lastText = text;
      _dismissed = false; // typing brings the suggestions back
    }
    _refresh();
  }

  void _refresh() {
    final selection = controller.selection;
    var next = const <CompletionItem>[];
    if (!_dismissed && selection.isValid && selection.isCollapsed) {
      final text = controller.text;
      final offset = selection.baseOffset.clamp(0, text.length);
      next = CompletionEngine.suggest(
        CompletionEngine.currentPrefix(text, offset),
        text,
      );
    }
    final unchanged = next.length == _suggestions.length &&
        next.map((e) => e.label).join('\u0000') ==
            _suggestions.map((e) => e.label).join('\u0000');
    if (unchanged) return;
    _suggestions = next;
    _selected = 0;
    notifyListeners();
  }

  /// Chooses the next suggestion (after the last comes the first).
  void selectNext() => _select(_selected + 1);

  /// Chooses the previous suggestion (before the first comes the last).
  void selectPrevious() => _select(_selected - 1);

  void _select(int index) {
    if (_suggestions.isEmpty) return;
    _selected = (index + _suggestions.length) % _suggestions.length;
    notifyListeners();
  }

  /// Hides the suggestions until the text changes again.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _refresh();
  }

  /// Inserts [item] in place of the word being typed and puts the cursor on
  /// its first stop (at the end of the text when it has none).
  void accept(CompletionItem item) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final text = controller.text;
    final cursor = selection.baseOffset.clamp(0, text.length);
    final start = cursor - CompletionEngine.currentPrefix(text, cursor).length;
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final baseIndent =
        RegExp(r'^[ \t]*').stringMatch(text.substring(lineStart, start)) ?? '';

    final snippet = expandSnippet(
      item.insertText,
      baseIndent: baseIndent,
      indentSize: indentSize,
    );
    final stops = [for (final stop in snippet.stops) start + stop];
    final end = start + snippet.text.length;

    _session = null; // set again below, once the new text is in
    controller.value = TextEditingValue(
      text: text.replaceRange(start, cursor, snippet.text),
      selection: TextSelection.collapsed(
        offset: stops.isEmpty ? end : stops.first,
      ),
    );
    if (stops.length > 1) {
      _session = SnippetSession(start, end, stops.sublist(1));
    }
  }

  /// Moves the cursor to the next stop of the snippet just inserted.
  /// False when there is none (or the cursor has left the snippet).
  bool jumpToNextStop() {
    final session = _session;
    if (session == null) return false;
    final cursor = controller.selection.baseOffset;
    final ahead =
        session.contains(cursor) ? session.stopsAfter(cursor) : const <int>[];
    if (ahead.isEmpty) {
      _session = null;
      return false;
    }
    _session = ahead.length > 1
        ? SnippetSession(session.start, session.end, ahead.sublist(1))
        : null;
    controller.value = controller.value.copyWith(
      selection: TextSelection.collapsed(offset: ahead.first),
    );
    return true;
  }
}
