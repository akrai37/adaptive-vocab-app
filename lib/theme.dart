import 'package:flutter/material.dart';

import 'config.dart';

/// Look and feel for young children: a rounded display font, bright colours
/// per category, soft shadows, and a warm background.

const _cream = Color(0xFFFFF6E5);
const ink = Color(0xFF2E2A47);

/// One bright colour per category. Falls back to [_extra] for new ones.
const _categoryColors = {
  'animals': Color(0xFFFF8A3D),
  'food': Color(0xFFFF5C7A),
  'body': Color(0xFFA06CF2),
  'home': Color(0xFF3FA7F5),
  'nature': Color(0xFF3CC46B),
  'sea': Color(0xFF1E88E5),
  'bugs': Color(0xFF8BC34A),
  'clothes': Color(0xFFEC6EC7),
  'school': Color(0xFFFFB020),
  'play': Color(0xFFFF7043),
  'transport': Color(0xFF5C6BC0),
  'music': Color(0xFF7E57C2),
  mixCategory: Color(0xFF14B8A6),
};
const _extra = [Color(0xFFFFC53D), Color(0xFF26C6DA), Color(0xFFEC6EC7)];

Color categoryColor(String category) =>
    _categoryColors[category] ?? _extra[category.hashCode % _extra.length];

/// Tile colour for the [i]th child on the picker.
Color kidColor(int i) {
  const palette = [
    Color(0xFFFF8A3D),
    Color(0xFF3FA7F5),
    Color(0xFFA06CF2),
    Color(0xFF3CC46B),
    Color(0xFFFF5C7A),
    Color(0xFF26C6DA),
    Color(0xFFEC6EC7),
    Color(0xFFFFB020),
  ];
  return palette[i % palette.length];
}

/// "animals" → "Animals".
String titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

ThemeData appTheme() {
  final base = ThemeData(
    colorSchemeSeed: const Color(0xFFFF8A3D),
    scaffoldBackgroundColor: _cream,
    fontFamily: 'Fredoka',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: _cream,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
  );
}

/// Big rounded heading used for the word being learned.
TextStyle wordStyle({double size = 64, Color color = ink}) => TextStyle(
  fontFamily: 'Fredoka',
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: color,
  height: 1.1,
);

/// A chunky tappable tile with a coloured body and a soft shadow.
class BigTile extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  const BigTile({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(32),
    elevation: 6,
    shadowColor: color.withValues(alpha: 0.5),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Center(child: child),
    ),
  );
}
