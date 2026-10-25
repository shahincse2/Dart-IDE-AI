/// Marks a place in a snippet where the cursor can stop: `print('§');` puts
/// the cursor between the quotes. The marker is never inserted into the text.
const String kStopMarker = '§';

/// A snippet ready to insert: its [text] and the places the cursor stops, as
/// offsets into [text], in order. The first stop is where the cursor goes
/// right after the insert; the others are for Tab.
class ExpandedSnippet {
  const ExpandedSnippet(this.text, this.stops);

  final String text;
  final List<int> stops;
}

/// Turns a snippet [template] into text to insert.
///
/// Templates use two spaces per indentation level. Every line after the first
/// is moved to where the snippet is inserted: it gets [baseIndent] (the
/// indentation of the line the snippet goes into) plus [indentSize] spaces
/// per level, so a snippet typed inside a function lines up with it.
ExpandedSnippet expandSnippet(
  String template, {
  String baseIndent = '',
  int indentSize = 2,
}) {
  final lines = template.split('\n');
  final reindented = StringBuffer(lines.first);
  for (final line in lines.skip(1)) {
    final spaces = line.length - line.trimLeft().length;
    final levels = spaces ~/ 2;
    reindented
      ..write('\n')
      ..write(baseIndent)
      ..write(' ' * (levels * indentSize))
      ..write(line.substring(spaces));
  }

  final text = StringBuffer();
  final stops = <int>[];
  for (final char in reindented.toString().split('')) {
    if (char == kStopMarker) {
      stops.add(text.length);
    } else {
      text.write(char);
    }
  }
  return ExpandedSnippet(text.toString(), stops);
}
