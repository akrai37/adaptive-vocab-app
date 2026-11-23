import 'dart:convert';

import 'package:flutter/services.dart';

import '../config.dart';
import '../models/word.dart';

/// The word list, loaded once from the bundled `content/words.json`.
class WordRepository {
  final List<String> categories;
  final List<Word> words;

  /// Group names per language: categoryNames['animals']['es'] = 'Animales'.
  final Map<String, Map<String, String>> categoryNames;

  WordRepository._(this.categories, this.words, this.categoryNames);

  /// What a child sees for [category] in [lang]; "animals" → "Animals"
  /// when the word list has no name for it.
  String categoryName(String category, String lang) =>
      categoryNames[category]?[lang] ??
      categoryNames[category]?['en'] ??
      (category.isEmpty
          ? category
          : category[0].toUpperCase() + category.substring(1));

  static Future<WordRepository> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString('content/words.json');
    return WordRepository.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory WordRepository.fromJson(Map<String, dynamic> json) =>
      WordRepository._(
        List<String>.from(json['categories'] as List),
        (json['words'] as List)
            .map((w) => Word.fromJson(w as Map<String, dynamic>))
            .toList(),
        {
          for (final MapEntry(:key, :value)
              in (json['categoryNames'] as Map? ?? const {}).entries)
            key as String: Map<String, String>.from(value as Map),
        },
      );

  /// Words for a round: every word for [mixCategory], else one category.
  List<Word> pool(String category) =>
      category == mixCategory ? words : inCategory(category);

  List<Word> inCategory(String category) =>
      words.where((w) => w.category == category).toList();

  Word byId(String id) => words.firstWhere((w) => w.id == id);
}
