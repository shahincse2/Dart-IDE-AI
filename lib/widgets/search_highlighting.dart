import 'package:flutter/material.dart';

import '../utils/highlight_spans.dart';

/// The Find & Replace highlights of a text controller: which matches the
/// search box currently finds, and which one is the current one.
mixin SearchHighlighting on TextEditingController {
  List<int> _searchMatchStarts = const [];
  int _searchMatchLength = 0;
  int _activeSearchMatch = -1;

  /// Sets which character ranges Find & Replace's search box currently
  /// matches, all the same length ([queryLength]), so they render with a
  /// highlight background. Pass an empty list to clear.
  void setSearchHighlights(List<int> matchStarts, [int queryLength = 0]) {
    _searchMatchStarts = matchStarts;
    _searchMatchLength = queryLength;
    if (matchStarts.isEmpty) _activeSearchMatch = -1;
    notifyListeners();
  }

  /// Marks which of [setSearchHighlights]'s matches (by index) is the
  /// "current" one Find & Replace is on — rendered with a stronger highlight
  /// than the others.
  void setActiveSearchMatch(int index) {
    _activeSearchMatch = index;
    notifyListeners();
  }

  /// What the text drawing paints.
  SearchHighlights get searchHighlights => SearchHighlights(
        starts: _searchMatchStarts,
        length: _searchMatchLength,
        active: _activeSearchMatch,
      );
}
