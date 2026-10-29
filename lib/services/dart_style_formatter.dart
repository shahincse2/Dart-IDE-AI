import 'dart:isolate';

import 'package:dart_style/dart_style.dart';

import 'code_formatter.dart';

/// Formats Dart with the same formatter as `dart format`.
///
/// The work runs in another isolate, so a long file never freezes the screen.
class DartStyleFormatter implements CodeFormatter {
  DartStyleFormatter({this.pageWidth = 80});

  /// Lines are wrapped at this width (the default of `dart format`).
  final int pageWidth;

  @override
  Future<FormatResult> format(String source, {int cursorOffset = 0}) {
    final width = pageWidth;
    return Isolate.run(() => _formatNow(source, cursorOffset, width));
  }
}

FormatResult _formatNow(String source, int cursorOffset, int pageWidth) {
  try {
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
      pageWidth: pageWidth,
    );
    final result = formatter.formatSource(
      SourceCode(
        source,
        selectionStart: cursorOffset.clamp(0, source.length).toInt(),
        selectionLength: 0,
      ),
    );
    if (result.text == source) return const FormatResult.unchanged();
    return FormatResult.formatted(result.text, result.selectionStart ?? 0);
  } on FormatterException catch (error) {
    return FormatResult.failed(_firstProblem(error, source));
  } catch (error) {
    return FormatResult.failed('$error');
  }
}

/// "line 3: Expected ';' after this." for the first syntax error.
String _firstProblem(FormatterException error, String source) {
  if (error.errors.isEmpty) return 'the code has a syntax error';
  final first = error.errors.first;
  final offset = first.offset.clamp(0, source.length).toInt();
  final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
  return 'line $line: ${first.message}';
}
