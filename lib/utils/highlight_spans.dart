import 'dart:collection';

import 'package:flutter/material.dart';

import 'dart_syntax_highlighter.dart';
import 'fold_regions.dart';
import 'hidden_text.dart';
import 'string_escapes.dart';
import 'themes.dart';
import 'token_colors.dart';

/// Find & Replace matches to paint: every match is [length] characters long,
/// starting at one of [starts]; [active] is the index of the current one.
class SearchHighlights {
  const SearchHighlights({
    this.starts = const [],
    this.length = 0,
    this.active = -1,
  });

  final List<int> starts;
  final int length;
  final int active;
}

/// Finds whichever token (if any) fully covers [start, end) — used to color a
/// breakpoint-delimited span. Gaps between tokens (plain whitespace or
/// punctuation not otherwise classified) return null, which callers render in
/// the default text color.
TokenType? _tokenTypeCovering(List<SyntaxToken> toks, int start, int end) {
  for (final t in toks) {
    if (t.start <= start && t.end >= end) return t.type;
    if (t.start >= end) break; // tokens are in source order
  }
  return null;
}

/// Builds the coloured text of the editor.
///
/// Every span in the output must respect independent sets of boundaries:
/// token edges (syntax color), the matched-bracket pair (single characters),
/// search-match ranges (arbitrary length), and folded (hidden) ranges.
/// Collect every boundary into one sorted breakpoint list, then build one
/// span per gap between consecutive breakpoints with whatever combination of
/// styling applies.
TextSpan buildHighlightedSpan({
  required String source,
  required TextStyle? style,
  required EditorColorScheme scheme,
  required List<SyntaxToken> tokens,
  required EscapeRanges escapes,
  required int? openBracket,
  required int? closeBracket,
  required SearchHighlights search,
  required List<CharRange> hidden,
}) {
  final hasBracket = openBracket != null && closeBracket != null;
  final breakpoints = SplayTreeSet<int>()..addAll([0, source.length]);
  for (final t in tokens) {
    breakpoints.add(t.start);
    breakpoints.add(t.end);
  }
  if (hasBracket) {
    breakpoints.add(openBracket);
    breakpoints.add(openBracket + 1);
    breakpoints.add(closeBracket);
    breakpoints.add(closeBracket + 1);
  }
  for (final matchStart in search.starts) {
    breakpoints.add(matchStart);
    breakpoints.add(matchStart + search.length);
  }
  for (final r in hidden) {
    breakpoints.add(r.start);
    breakpoints.add(r.end);
  }
  breakpoints.addAll(escapes.boundaries);
  final sorted =
      breakpoints.where((b) => b >= 0 && b <= source.length).toList();

  final children = <TextSpan>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final start = sorted[i];
    final end = sorted[i + 1];
    if (start >= end) continue;

    final hiddenRange =
        hidden.isEmpty ? null : hiddenRangeCovering(hidden, start, end);
    if (hiddenRange != null) {
      children.add(
        TextSpan(
          text: hiddenText(
            source.substring(start, end),
            endsRange: end == hiddenRange.end,
          ),
          style: hiddenStyle(style),
        ),
      );
      continue;
    }

    final tokenType = _tokenTypeCovering(tokens, start, end);
    final isBracketMatch = hasBracket &&
        end - start == 1 &&
        (start == openBracket || start == closeBracket);

    var searchMatchIndex = -1;
    for (var m = 0; m < search.starts.length; m++) {
      final matchStart = search.starts[m];
      if (start >= matchStart && end <= matchStart + search.length) {
        searchMatchIndex = m;
        break;
      }
    }
    final isSearchMatch = searchMatchIndex != -1;
    final isActiveSearchMatch =
        isSearchMatch && searchMatchIndex == search.active;

    Color? backgroundColor;
    if (isActiveSearchMatch) {
      backgroundColor = scheme.operatorColor.withValues(alpha: 0.55);
    } else if (isSearchMatch) {
      backgroundColor = scheme.selection.withValues(alpha: 0.35);
    } else if (isBracketMatch) {
      backgroundColor = scheme.selection.withValues(alpha: 0.55);
    }

    children.add(
      TextSpan(
        text: source.substring(start, end),
        style: style?.copyWith(
          color: escapes.covers(start, end)
              ? scheme.operatorColor
              : (tokenType != null
                  ? colorForToken(scheme, tokenType)
                  : scheme.text),
          backgroundColor: backgroundColor,
          fontWeight: isBracketMatch ? FontWeight.w700 : null,
        ),
      ),
    );
  }

  return TextSpan(style: style, children: children);
}
