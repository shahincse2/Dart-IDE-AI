import 'package:flutter/material.dart';

import '../utils/dart_syntax_highlighter.dart';
import '../utils/fold_model.dart';
import '../utils/fold_ranges.dart';
import '../utils/fold_regions.dart';

/// Code folding for a text controller.
///
/// A fold never changes the controller's text: folded lines stay in it (so
/// save, run, undo, find, share all keep working on the full source) and are
/// only DRAWN invisible. The state itself is a [FoldModel]; this mixin ties
/// it to the text and the selection.
mixin CodeFolding on TextEditingController {
  final FoldModel _folds = FoldModel();

  /// The syntax tokens of the current text (folds ignore brackets inside
  /// strings and comments).
  List<SyntaxToken> get tokens;

  void _syncFolds() => _folds.sync(text, () => foldSkipRanges(tokens));

  /// Every foldable region in the current text (sorted by start line). The
  /// same list object until the text changes.
  List<FoldRegion> get foldRegions {
    _syncFolds();
    return _folds.regions;
  }

  /// Start lines of the regions currently folded (sorted).
  List<int> get foldedStartLines {
    _syncFolds();
    return _folds.foldedStarts;
  }

  /// Merged, sorted, inclusive line ranges that are currently hidden.
  List<LineRange> get hiddenLineRanges {
    _syncFolds();
    return _folds.hiddenLines;
  }

  /// Changes whenever the set of hidden lines changes (a cache key).
  String get hiddenSignature {
    _syncFolds();
    return _folds.hiddenSignature;
  }

  bool get hasFolds {
    _syncFolds();
    return _folds.hasHidden;
  }

  bool isFolded(int startLine) {
    _syncFolds();
    return _folds.isFolded(startLine);
  }

  /// Folds the region starting at [startLine], or unfolds it if it is already
  /// folded. Does nothing if no region starts on that line.
  void toggleFold(int startLine) {
    _syncFolds();
    final nowFolded = _folds.toggle(startLine);
    if (nowFolded == null) return;
    nowFolded ? _moveSelectionOutOfHidden() : notifyListeners();
  }

  void foldAll() {
    _syncFolds();
    if (_folds.foldAll()) _moveSelectionOutOfHidden();
  }

  void unfoldAll() {
    if (_folds.unfoldAll()) notifyListeners();
  }

  // ---- For the controller that uses this mixin ------------------------------

  /// The character ranges drawn invisible right now (empty without folds).
  @protected
  List<CharRange> get hiddenChars {
    if (!_folds.hasFolded) return const [];
    _syncFolds();
    return _folds.hiddenChars;
  }

  /// Called just before the text changes from the current text to [newText]:
  /// the folds follow the code, and any the edit touches are unfolded.
  @protected
  void followEdit(String newText) {
    if (!_folds.hasFolded) return;
    _syncFolds();
    _folds.remapForEdit(text, newText);
  }

  /// Unfolds whatever hides the (1-indexed) [line].
  @protected
  void unfoldLine(int line) {
    if (!_folds.hasFolded) return;
    _syncFolds();
    _folds.unfoldHiding(line - 1);
  }

  /// If the selection landed inside hidden text (arrow keys, Find, Go to
  /// line...), unfold whatever hides it.
  @protected
  void unfoldIfSelectionHidden() {
    if (!_folds.hasFolded) return;
    _syncFolds();
    final sel = selection;
    if (!sel.isValid || _folds.hiddenChars.isEmpty) return;

    var changed = false;
    for (final offset in {sel.baseOffset, sel.extentOffset}) {
      if (offset < 0) continue;
      if (_folds.unfoldHiding(_folds.lineOfOffset(offset))) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// After a fold: if the cursor/selection ended up inside hidden text, move
  /// it to the end of the visible line just above the fold.
  void _moveSelectionOutOfHidden() {
    final sel = selection;
    if (!sel.isValid) {
      notifyListeners();
      return;
    }

    int fix(int offset) {
      for (final r in _folds.hiddenChars) {
        if (offset >= r.start && offset < r.end) {
          return r.start - 1; // end of the start line, before its '\n'
        }
      }
      return offset;
    }

    final base = fix(sel.baseOffset);
    final extent = fix(sel.extentOffset);
    if (base != sel.baseOffset || extent != sel.extentOffset) {
      // Not the controller's own `value` setter: moving the cursor is not an
      // edit (no auto-indent, no auto-pair).
      super.value = value.copyWith(
        selection: TextSelection(baseOffset: base, extentOffset: extent),
      );
    } else {
      notifyListeners();
    }
  }
}
