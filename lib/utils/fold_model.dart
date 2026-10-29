import 'fold_ranges.dart';
import 'fold_regions.dart';
import 'fold_remap.dart';

/// Which regions of a text can be folded and which are folded.
///
/// The text itself is never changed by a fold. Fold state is stored as the
/// start line of each folded region; [remapForEdit] keeps it following the
/// code when lines are added or removed above it. The controller that owns
/// the text decides what a fold does to the selection.
class FoldModel {
  final Set<int> _folded = {};
  String? _cacheText;
  List<FoldRegion> _regions = const [];
  List<int> _lineStarts = const [0];
  List<LineRange> _hiddenLines = const [];
  List<CharRange> _hiddenChars = const [];

  /// Every foldable region (sorted by start line), as of the last [sync].
  List<FoldRegion> get regions => _regions;

  /// Merged, sorted, inclusive line ranges that are currently hidden.
  List<LineRange> get hiddenLines => _hiddenLines;

  /// The same ranges as character offsets.
  List<CharRange> get hiddenChars => _hiddenChars;

  bool get hasFolded => _folded.isNotEmpty;
  bool get hasHidden => _hiddenLines.isNotEmpty;

  /// Start lines of the regions currently folded (sorted).
  List<int> get foldedStarts => _folded.toList()..sort();

  /// Changes whenever the set of hidden lines changes. Handy as a cache key.
  String get hiddenSignature {
    if (_hiddenLines.isEmpty) return '';
    return _hiddenLines.map((r) => '${r.first}-${r.last}').join(',');
  }

  bool isFolded(int startLine) => _folded.contains(startLine);

  /// Recomputes regions / line starts when [text] changed. [skipRanges] is
  /// only called then (finding tokens is not free).
  void sync(String text, List<int> Function() skipRanges) {
    if (_cacheText == text) return;
    _cacheText = text;
    _lineStarts = computeLineStarts(text);
    _regions = computeFoldRegions(text, skipRanges());
    _rebuildHidden();
  }

  /// Folds the region starting at [startLine], or unfolds it if it is folded.
  /// Null: no region starts on that line. True: it is folded now.
  bool? toggle(int startLine) {
    if (!_regions.any((r) => r.startLine == startLine)) return null;
    final nowFolded = !_folded.remove(startLine);
    if (nowFolded) _folded.add(startLine);
    _rebuildHidden();
    return nowFolded;
  }

  /// False when there is nothing to fold.
  bool foldAll() {
    if (_regions.isEmpty) return false;
    _folded
      ..clear()
      ..addAll(_regions.map((r) => r.startLine));
    _rebuildHidden();
    return true;
  }

  /// False when nothing was folded.
  bool unfoldAll() {
    if (_folded.isEmpty) return false;
    _folded.clear();
    _rebuildHidden();
    return true;
  }

  /// Unfolds every region that hides [line]. False when none did.
  bool unfoldHiding(int line) {
    final toRemove = <int>[];
    for (final r in _regions) {
      if (_folded.contains(r.startLine) &&
          line > r.startLine &&
          line < r.endLine) {
        toRemove.add(r.startLine);
      }
    }
    if (toRemove.isEmpty) return false;
    _folded.removeAll(toRemove);
    _rebuildHidden();
    return true;
  }

  /// The line the character at [offset] is on.
  int lineOfOffset(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Called just before the text changes from [oldText] (the text of the last
  /// [sync]) to [newText]: the folds follow the code, and any the edit
  /// touches are unfolded.
  void remapForEdit(String oldText, String newText) {
    if (_folded.isEmpty) return;
    final survivors = remapFoldedStarts(
      oldText: oldText,
      newText: newText,
      regions: _regions,
      folded: _folded,
      lineStarts: _lineStarts,
    );
    _folded
      ..clear()
      ..addAll(survivors);
  }

  /// Rebuilds the hidden line/char ranges from the folded start lines, first
  /// dropping any folded start line that no longer has a region.
  void _rebuildHidden() {
    final byStart = <int, FoldRegion>{
      for (final r in _regions) r.startLine: r,
    };
    _folded.removeWhere((line) => !byStart.containsKey(line));

    final folded = _folded.map((l) => byStart[l]!).toList()
      ..sort((a, b) => a.startLine.compareTo(b.startLine));

    _hiddenLines = mergeHiddenLines(folded);
    _hiddenChars = hiddenCharRanges(
      _hiddenLines,
      _lineStarts,
      _cacheText?.length ?? 0,
    );
  }
}
