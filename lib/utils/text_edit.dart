import 'dart:math' as math;

/// What changed between two versions of a text: the part `[start, oldEnd)`
/// of the old text was replaced by `[start, newEnd)` of the new one.
class TextEdit {
  const TextEdit(this.start, this.oldEnd, this.newEnd);

  final int start;
  final int oldEnd;
  final int newEnd;

  /// How much longer the text became (negative: shorter).
  int get delta => newEnd - oldEnd;

  factory TextEdit.between(String oldText, String newText) {
    final shortest = math.min(oldText.length, newText.length);
    var prefix = 0;
    while (prefix < shortest &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) ==
            newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }
    return TextEdit(prefix, oldText.length - suffix, newText.length - suffix);
  }

  /// Where a place that was at [offset] in the old text is in the new one.
  /// Null when it was inside the replaced part: that place is gone.
  int? shift(int offset) {
    if (offset <= start) return offset;
    if (offset >= oldEnd) return offset + delta;
    return null;
  }
}
