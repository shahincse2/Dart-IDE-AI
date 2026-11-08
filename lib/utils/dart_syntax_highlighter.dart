/// A lightweight, heuristic Dart tokenizer for syntax highlighting.
///
/// This is NOT a full language parser — it's a regex/scanner-based lexer
/// good enough for coloring code as you type on a phone.
///
/// Known simplifications:
///   - Triple-quoted multiline strings aren't given special handling.
///   - Type detection is heuristic (capitalized identifier, or a small
///     built-in-types list), not symbol-table-based.
///   - String interpolation is tokenized so interpolated variables and
///     expressions can receive their own syntax colors.
///   - This is still not a full Dart parser, so complex interpolation
///     expressions may have minor highlighting differences from a full IDE.
///
/// The pieces live in `dart_syntax/`: the token types, the word lists, one
/// scanner per kind of token, and the tokenizer that ties them together.
library;

export 'dart_syntax/token_types.dart';
export 'dart_syntax/tokenizer.dart' show tokenizeDart;
