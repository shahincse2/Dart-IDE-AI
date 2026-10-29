import 'text_edit.dart';

/// The cursor stops still ahead after a snippet was inserted.
class SnippetSession {
  const SnippetSession(this.start, this.end, this.stops);

  /// The inserted snippet occupies `[start, end]` of the text.
  final int start;
  final int end;

  /// Places Tab still goes to, in text order.
  final List<int> stops;

  /// Whether the cursor is still inside the snippet.
  bool contains(int offset) => offset >= start && offset <= end;

  /// The stops after [cursor].
  List<int> stopsAfter(int cursor) => [
        for (final stop in stops)
          if (stop > cursor) stop,
      ];

  /// The session after the text changed by [edit]: the stops after the edit
  /// move along with the text, any the edit replaced are gone. Null when
  /// nothing is left of it.
  SnippetSession? followEdit(TextEdit edit) {
    final newStart = edit.shift(start);
    final newEnd = edit.shift(end);
    final newStops = [
      for (final stop in stops) edit.shift(stop),
    ].whereType<int>().toList();
    if (newStart == null || newEnd == null || newStops.isEmpty) return null;
    return SnippetSession(newStart, newEnd, newStops);
  }
}
