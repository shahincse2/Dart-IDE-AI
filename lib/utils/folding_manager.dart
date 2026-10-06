import 'package:flutter/foundation.dart';

/// A foldable block: a range of lines that can be collapsed.
class FoldableBlock {
  final int startLine; // 0-indexed, the line with the opening brace
  final int endLine; // 0-indexed, the line with the closing brace

  const FoldableBlock({
    required this.startLine,
    required this.endLine,
  });
}

/// Tracks which blocks are folded and notifies listeners when the
/// folding state changes.
class FoldingManager extends ChangeNotifier {
  final Set<int> _foldedStartLines = {};

  bool isFolded(int startLine) => _foldedStartLines.contains(startLine);

  void fold(int startLine) {
    if (_foldedStartLines.add(startLine)) {
      notifyListeners();
    }
  }

  void unfold(int startLine) {
    if (_foldedStartLines.remove(startLine)) {
      notifyListeners();
    }
  }

  void toggle(int startLine) {
    if (isFolded(startLine)) {
      unfold(startLine);
    } else {
      fold(startLine);
    }
  }

  /// Scans [source] for brace-delimited blocks (functions, classes,
  /// if/for/while bodies) and returns them sorted by start line.
  /// Only blocks spanning at least 2 lines are returned.
  static List<FoldableBlock> detectBlocks(String source) {
    final lines = source.split('\n');
    final blocks = <FoldableBlock>[];
    final stack = <int>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final opens = '{'.allMatches(line).length;
      final closes = '}'.allMatches(line).length;

      for (var o = 0; o < opens; o++) {
        stack.add(i);
      }

      for (var c = 0; c < closes; c++) {
        if (stack.isNotEmpty) {
          final startLine = stack.removeLast();

          if (i - startLine >= 2) {
            blocks.add(
              FoldableBlock(
                startLine: startLine,
                endLine: i,
              ),
            );
          }
        }
      }
    }

    blocks.sort(
      (a, b) => a.startLine.compareTo(b.startLine),
    );

    return blocks;
  }

  /// Returns the source with folded blocks collapsed to a single line.
  ///
  /// NOTE:
  /// This method is intentionally NOT used to replace the editor's
  /// controller text. The editor must keep the original source so
  /// running the program still executes the real code.
  String applyFolding(String source) {
    if (_foldedStartLines.isEmpty) return source;

    final lines = source.split('\n');
    final blocks = detectBlocks(source);

    final foldedBlocks = blocks
        .where(
          (b) => _foldedStartLines.contains(b.startLine),
        )
        .toList();

    if (foldedBlocks.isEmpty) return source;

    final result = <String>[];
    var i = 0;

    while (i < lines.length) {
      final block = foldedBlocks.where((b) => b.startLine == i).firstOrNull;

      if (block != null) {
        result.add('${lines[i]} … }');
        i = block.endLine + 1;
      } else {
        result.add(lines[i]);
        i++;
      }
    }

    return result.join('\n');
  }

  /// Returns all currently folded block start lines.
  Set<int> get foldedStartLines => Set.unmodifiable(_foldedStartLines);
}

// /// A foldable block: a range of lines that can be collapsed.
// class FoldableBlock {
//   final int startLine; // 0-indexed, the line with the opening brace
//   final int endLine;   // 0-indexed, the line with the closing brace
//
//   const FoldableBlock({required this.startLine, required this.endLine});
// }
//
// /// Tracks which blocks are folded and computes the visible text
// /// (with folded ranges replaced by a placeholder).
// class FoldingManager {
//   final Set<int> _foldedStartLines = {};
//
//   bool isFolded(int startLine) => _foldedStartLines.contains(startLine);
//
//   void fold(int startLine) => _foldedStartLines.add(startLine);
//
//   void unfold(int startLine) => _foldedStartLines.remove(startLine);
//
//   void toggle(int startLine) {
//     if (isFolded(startLine)) {
//       unfold(startLine);
//     } else {
//       fold(startLine);
//     }
//   }
//
//   /// Scans [source] for brace-delimited blocks (functions, classes,
//   /// if/for/while bodies) and returns them sorted by start line.
//   /// Only blocks spanning at least 2 lines are returned.
//   static List<FoldableBlock> detectBlocks(String source) {
//     final lines = source.split('\n');
//     final blocks = <FoldableBlock>[];
//     final stack = <int>[];
//
//     for (var i = 0; i < lines.length; i++) {
//       final line = lines[i];
//       final opens = '{'.allMatches(line).length;
//       final closes = '}'.allMatches(line).length;
//
//       for (var o = 0; o < opens; o++) {
//         stack.add(i);
//       }
//       for (var c = 0; c < closes; c++) {
//         if (stack.isNotEmpty) {
//           final startLine = stack.removeLast();
//           if (i - startLine >= 2) {
//             blocks.add(FoldableBlock(startLine: startLine, endLine: i));
//           }
//         }
//       }
//     }
//
//     blocks.sort((a, b) => a.startLine.compareTo(b.startLine));
//     return blocks;
//   }
//
//   /// Returns the source with folded blocks collapsed to a single line.
//   String applyFolding(String source) {
//     if (_foldedStartLines.isEmpty) return source;
//
//     final lines = source.split('\n');
//     final blocks = detectBlocks(source);
//     final foldedBlocks = blocks
//         .where((b) => _foldedStartLines.contains(b.startLine))
//         .toList();
//
//     if (foldedBlocks.isEmpty) return source;
//
//     final result = <String>[];
//     var i = 0;
//     while (i < lines.length) {
//       final block = foldedBlocks.where((b) => b.startLine == i).firstOrNull;
//       if (block != null) {
//         result.add('${lines[i]} … }');
//         i = block.endLine + 1;
//       } else {
//         result.add(lines[i]);
//         i++;
//       }
//     }
//     return result.join('\n');
//   }
// }
