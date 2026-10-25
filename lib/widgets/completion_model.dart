import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../utils/completion_engine.dart';
import '../utils/snippet_template.dart';
import '../utils/text_edit.dart';
import 'code_editor_controller.dart';

/// The cursor stops still ahead after a snippet was inserted.
class _Session {
  const _Session(this.start, this.end, this.stops);

  /// The inserted snippet occupies `[start, end]` of the text.
  final int start;
  final int end;

  /// Places Tab still goes to, in text order.
  final List<int> stops;
}

/// What is suggested for the word at the cursor, and what accepting a
/// suggestion does: the text is inserted (a snippet is lined up with the line
/// it goes into), the cursor lands on the snippet's first stop, and Tab walks
/// through the other stops.
///
/// Tab itself: with suggestions showing it accepts the first one; otherwise,
/// right after a snippet, it moves to the next stop. In any other case the key
/// is left alone ([handleKey] says "ignored").
class CompletionModel extends ChangeNotifier {
  CompletionModel(this.controller) : _lastText = controller.text {
    controller.addListener(_onControllerChanged);
    _refresh();
  }

  final CodeEditorController controller;

  /// Spaces per indentation level for inserted snippets.
  int indentSize = 2;

  List<CompletionItem> _suggestions = const [];
  _Session? _session;
  String _lastText;
  bool _tabHandled = false;

  List<CompletionItem> get suggestions => _suggestions;
  bool get hasSuggestions => _suggestions.isNotEmpty;

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = controller.text;
    if (text != _lastText) {
      _followEdit(_lastText, text);
      _lastText = text;
    }
    _refresh();
  }

  void _refresh() {
    final selection = controller.selection;
    var next = const <CompletionItem>[];
    if (selection.isValid && selection.isCollapsed) {
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
    notifyListeners();
  }

  /// The text changed from [oldText] to [newText]: the stops after the edit
  /// move along with the text, and any the edit replaced are gone.
  void _followEdit(String oldText, String newText) {
    final session = _session;
    if (session == null) return;
    final edit = TextEdit.between(oldText, newText);
    final start = edit.shift(session.start);
    final end = edit.shift(session.end);
    final stops = [
      for (final stop in session.stops) edit.shift(stop),
    ].whereType<int>().toList();
    if (start == null || end == null || stops.isEmpty) {
      _session = null;
      return;
    }
    _session = _Session(start, end, stops);
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
      _session = _Session(start, end, stops.sublist(1));
    }
  }

  /// Moves the cursor to the next stop of the snippet just inserted.
  /// False when there is none (or the cursor has left the snippet).
  bool jumpToNextStop() {
    final session = _session;
    if (session == null) return false;
    final cursor = controller.selection.baseOffset;
    if (cursor < session.start || cursor > session.end) {
      _session = null;
      return false;
    }
    final ahead = session.stops.where((stop) => stop > cursor).toList();
    if (ahead.isEmpty) {
      _session = null;
      return false;
    }
    _session = ahead.length > 1
        ? _Session(session.start, session.end, ahead.sublist(1))
        : null;
    controller.value = controller.value.copyWith(
      selection: TextSelection.collapsed(offset: ahead.first),
    );
    return true;
  }

  /// Tab accepts the first suggestion, or moves to the next stop of a snippet.
  /// Anything else (and Shift+Tab) is left to the system.
  KeyEventResult handleKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.tab) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      _tabHandled = false;
      return KeyEventResult.ignored;
    }
    // A held key repeats: it must not accept or jump again.
    if (event is KeyRepeatEvent) {
      return _tabHandled ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;

    if (hasSuggestions) {
      accept(_suggestions.first);
      _tabHandled = true;
      return KeyEventResult.handled;
    }
    if (jumpToNextStop()) {
      _tabHandled = true;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
