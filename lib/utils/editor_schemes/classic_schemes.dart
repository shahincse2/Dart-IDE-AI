import 'package:flutter/material.dart';

import '../editor_color_scheme.dart';

/// The classic editor themes, using their well-known real palettes.
const draculaScheme = EditorColorScheme(
  name: 'Dracula',
  background: Color(0xFF282A36),
  gutterBackground: Color(0xFF282A36),
  gutterText: Color(0xFF6272A4),
  text: Color(0xFFF8F8F2),
  currentLine: Color(0xFF44475A),
  selection: Color(0xFF44475A),
  cursor: Color(0xFFF8F8F0),

  // Syntax colors
  keyword: Color(0xFFFF79C6),
  string: Color(0xFFF1FA8C),
  comment: Color(0xFF6272A4),
  number: Color(0xFFBD93F9),
  annotation: Color(0xFFFFB86C),
  function: Color(0xFF50FA7B),
  type: Color(0xFF8BE9FD),
  variable: Color(0xFFF8F8F2),
  operatorColor: Color(0xFFFF79C6),
  punctuation: Color(0xFFF8F8F2),
);

const monokaiScheme = EditorColorScheme(
  name: 'Monokai',
  background: Color(0xFF272822),
  gutterBackground: Color(0xFF272822),
  gutterText: Color(0xFF75715E),
  text: Color(0xFFF8F8F2),
  currentLine: Color(0xFF3E3D32),
  selection: Color(0xFF49483E),
  cursor: Color(0xFFF8F8F0),

  // Syntax colors
  keyword: Color(0xFFF92672),
  string: Color(0xFFE6DB74),
  comment: Color(0xFF75715E),
  number: Color(0xFFAE81FF),
  annotation: Color(0xFF66D9EF),
  function: Color(0xFFA6E22E),
  type: Color(0xFF66D9EF),
  variable: Color(0xFFF8F8F2),
  operatorColor: Color(0xFFF92672),
  punctuation: Color(0xFFF8F8F2),
);

const oneDarkScheme = EditorColorScheme(
  name: 'One Dark',
  background: Color(0xFF282C34),
  gutterBackground: Color(0xFF282C34),
  gutterText: Color(0xFF495162),
  text: Color(0xFFABB2BF),
  currentLine: Color(0xFF2C313A),
  selection: Color(0xFF3E4451),
  cursor: Color(0xFF528BFF),
  keyword: Color(0xFFC678DD),
  string: Color(0xFF98C379),
  comment: Color(0xFF5C6370),
  number: Color(0xFFD19A66),
  annotation: Color(0xFFE5C07B),
  function: Color(0xFF61AFEF),
  type: Color(0xFFE5C07B),
  variable: Color(0xFFE06C75),
  operatorColor: Color(0xFF56B6C2),
  punctuation: Color(0xFFABB2BF),
);
