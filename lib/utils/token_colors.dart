import 'package:flutter/material.dart';

import 'dart_syntax_highlighter.dart';
import 'themes.dart';

/// The colour a syntax token is drawn in under [scheme].
Color colorForToken(EditorColorScheme scheme, TokenType type) {
  switch (type) {
    case TokenType.keyword:
      return scheme.keyword;
    case TokenType.string:
      return scheme.string;
    case TokenType.comment:
      return scheme.comment;
    case TokenType.number:
      return scheme.number;
    case TokenType.annotation:
      return scheme.annotation;
    case TokenType.type:
      return scheme.type;
    case TokenType.function:
      return scheme.function;
    case TokenType.variable:
      return scheme.variable;
    case TokenType.operatorSymbol:
      return scheme.operatorColor;
    case TokenType.punctuation:
      return scheme.punctuation;
  }
}
