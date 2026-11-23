import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/data/word_repository.dart';

void main() {
  final repo = WordRepository.fromJson(
    jsonDecode(File('content/words.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('loads every word with English text, a fact, and a picture', () {
    expect(repo.words.length, greaterThanOrEqualTo(140));
    expect(repo.categories.length, greaterThanOrEqualTo(12));
    for (final w in repo.words) {
      expect(w.text['en'], isNotEmpty, reason: w.id);
      expect(w.factIn('en'), isNotEmpty, reason: w.id);
      expect(File('content/${w.image}').existsSync(), isTrue, reason: w.id);
    }
  });

  test('every word and group has Spanish, with its article', () {
    final spanish = <String>{};
    for (final w in repo.words) {
      final es = w.text['es'];
      expect(es, matches(RegExp(r'^(el|la|los|las) ')), reason: w.id);
      expect(w.fact['es'], isNotEmpty, reason: w.id);
      expect(w.fact['es']!.length, lessThan(60), reason: w.id);
      spanish.add(es!);
    }
    expect(spanish, hasLength(repo.words.length), reason: 'no two the same');
    for (final c in repo.categories) {
      expect(
        repo.categoryName(c, 'es'),
        isNot(repo.categoryName(c, 'en')),
        reason: c,
      );
    }
    expect(repo.categoryName('animals', 'es'), 'Animales');
    expect(repo.byId('cat').label('es'), 'el gato');
  });

  test('every group has enough words for a round', () {
    for (final c in repo.categories) {
      expect(repo.inCategory(c).length, greaterThanOrEqualTo(8), reason: c);
    }
  });

  test('facts are short enough to read aloud', () {
    for (final w in repo.words) {
      expect(w.factIn('en')!.length, lessThan(60), reason: w.id);
    }
  });

  test('ids are unique', () {
    final ids = repo.words.map((w) => w.id).toSet();
    expect(ids, hasLength(repo.words.length));
  });

  test('every word belongs to a listed category', () {
    for (final w in repo.words) {
      expect(repo.categories, contains(w.category), reason: w.id);
    }
  });

  test('inCategory and byId', () {
    expect(repo.inCategory('animals'), hasLength(16));
    expect(repo.byId('cat').label('en'), 'cat');
    expect(repo.byId('cat').label('pt'), 'cat'); // falls back to English
  });
}
