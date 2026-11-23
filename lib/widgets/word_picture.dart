import 'package:flutter/material.dart';

import '../models/word.dart';

/// The picture for a word, from the bundled image file. Falls back to the
/// word's emoji if the file is missing.
class WordPicture extends StatelessWidget {
  final Word word;
  final double size;

  const WordPicture(this.word, {super.key, this.size = 96});

  @override
  Widget build(BuildContext context) => Image.asset(
    'content/${word.image}',
    width: size,
    height: size,
    semanticLabel: word.id,
    errorBuilder: (_, _, _) => Text(
      word.emoji,
      style: TextStyle(fontSize: size * 0.8, height: 1.1),
      semanticsLabel: word.id,
    ),
  );
}
