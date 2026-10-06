import '../utils/dart_syntax_highlighter.dart';

/// A completion suggestion with a label and the text to insert.
class CompletionItem {
  final String label;
  final String insertText;
  final CompletionKind kind;

  const CompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
  });
}

enum CompletionKind { keyword, snippet, identifier }

/// Generates code completion suggestions for a given prefix.
///
/// Two sources:
///   1. Dart keywords and common snippets (static list)
///   2. Identifiers already present in the current source (dynamic)
///
/// This is a heuristic engine — no type inference, no symbol table.
/// It matches by prefix only, which is enough for a mobile learning IDE.
class CompletionEngine {
  static const List<CompletionItem> _snippets = [
    CompletionItem(
      label: 'main',
      insertText: 'void main() {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'print',
      insertText: "print('');",
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'for',
      insertText: 'for (var i = 0; i < ; i++) {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'for-in',
      insertText: 'for (var item in ) {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'while',
      insertText: 'while () {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'if',
      insertText: 'if () {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'if-else',
      insertText: 'if () {\n  \n} else {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'switch',
      insertText:
          'switch () {\n  case :\n    break;\n  default:\n    break;\n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'class',
      insertText: 'class  {\n  \n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'void',
      insertText: 'void ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'var',
      insertText: 'var ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'final',
      insertText: 'final ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'const',
      insertText: 'const ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'return',
      insertText: 'return ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'import',
      insertText: "import '';",
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'package',
      insertText: 'package: ',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'async',
      insertText: 'async ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'await',
      insertText: 'await ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'Future',
      insertText: 'Future<>',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'List',
      insertText: 'List<>',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'Map',
      insertText: 'Map<, >',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'String',
      insertText: 'String ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'int',
      insertText: 'int ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'double',
      insertText: 'double ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'bool',
      insertText: 'bool ',
      kind: CompletionKind.keyword,
    ),
    CompletionItem(
      label: 'try-catch',
      insertText: 'try {\n  \n} catch (e) {\n  print(e);\n}',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'readLineSync',
      insertText: 'await readLineSync();',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdin',
      insertText: 'stdin',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout',
      insertText: 'stdout',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdin.readLineSync',
      insertText: 'await readLineSync();',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.write',
      insertText: 'write()',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.writeln',
      insertText: 'writeln()',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.writeLine',
      insertText: 'writeln()',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.writeLineSync',
      insertText: 'writeln()',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.writeSync',
      insertText: 'write()',
      kind: CompletionKind.snippet,
    ),
    CompletionItem(
      label: 'stdout.write',
      insertText: 'write()',
      kind: CompletionKind.snippet,
    ),
  ];

  /// Returns up to [maxResults] suggestions matching [prefix].
  static List<CompletionItem> suggest(
    String prefix,
    String fullSource, {
    int maxResults = 8,
  }) {
    if (prefix.isEmpty) return const [];

    final lower = prefix.toLowerCase();
    final results = <CompletionItem>[];

    // 1. Snippets and keywords first.
    for (final item in _snippets) {
      if (item.label.toLowerCase().startsWith(lower)) {
        results.add(item);
      }
    }

    // 2. Identifiers from the source (excluding duplicates already in list).
    final existingLabels = results.map((e) => e.label).toSet();
    final identifiers = _extractIdentifiers(fullSource);
    for (final id in identifiers) {
      if (id.toLowerCase().startsWith(lower) &&
          id != prefix &&
          !existingLabels.contains(id)) {
        results.add(CompletionItem(
          label: id,
          insertText: id,
          kind: CompletionKind.identifier,
        ));
        existingLabels.add(id);
      }
    }

    return results.take(maxResults).toList();
  }

  /// Extracts unique identifier names from source using the tokenizer.
  static List<String> _extractIdentifiers(String source) {
    if (source.isEmpty) return const [];
    final tokens = tokenizeDart(source);
    final seen = <String>{};
    final result = <String>[];
    for (final token in tokens) {
      if (token.type == TokenType.variable ||
          token.type == TokenType.function ||
          token.type == TokenType.type) {
        final text = source.substring(token.start, token.end);
        if (text.length > 1 && seen.add(text)) {
          result.add(text);
        }
      }
    }
    return result;
  }

  /// Extracts the word currently being typed at [cursorOffset].
  static String currentPrefix(String source, int cursorOffset) {
    if (cursorOffset <= 0 || source.isEmpty) return '';
    final before = source.substring(0, cursorOffset);
    final match = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*$').firstMatch(before);
    return match?.group(0) ?? '';
  }
}
