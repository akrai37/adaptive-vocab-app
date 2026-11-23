import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/logic/selector.dart';
import 'package:vocab_app/logic/stats.dart';
import 'package:vocab_app/models/activity.dart';
import 'package:vocab_app/models/answer.dart';
import 'package:vocab_app/models/word.dart';

Word word(String id, String category) => Word(
  id: id,
  category: category,
  emoji: '?',
  image: 'images/$id.png',
  text: {'en': id},
  audio: {'en': null},
);

final t0 = DateTime(2026, 10, 17, 9);

Answer answer(
  String wordId,
  int seconds, {
  String? chosen,
  Activity activity = Activity.pictureQuiz,
}) => Answer(
  activityType: activity.key,
  wordId: wordId,
  chosen: chosen ?? wordId,
  correct: (chosen ?? wordId) == wordId,
  latencyMs: 1500,
  timestamp: t0.add(Duration(seconds: seconds)),
);

void main() {
  final fruit = [
    'apple',
    'orange',
    'grape',
    'banana',
  ].map((w) => word(w, 'food'));
  final animals = ['cat', 'dog', 'cow', 'pig'].map((w) => word(w, 'animals'));
  final all = [...fruit, ...animals];

  group('buildStats', () {
    test('correct answers raise the box, a miss resets it', () {
      final s = buildStats([
        answer('apple', 0),
        answer('apple', 10),
        answer('apple', 20, chosen: 'orange'),
        answer('apple', 30),
      ])['apple']!;
      expect(s.shown, 4);
      expect(s.missed, 1);
      expect(s.box, 1);
      expect(s.confusions, {'orange': 1});
      expect(s.lastSeen, t0.add(const Duration(seconds: 30)));
    });

    test('box is capped', () {
      final s = buildStats([for (var i = 0; i < 9; i++) answer('cat', i)]);
      expect(s['cat']!.box, maxBox);
    });

    test('flashcards count as seen but do not change the box', () {
      final s = buildStats([
        answer('cat', 0, activity: Activity.flashcard),
        answer('cat', 5, activity: Activity.flashcard),
      ])['cat']!;
      expect(s.shown, 2);
      expect(s.box, 0);
      expect(s.missed, 0);
    });
  });

  group('selectWord', () {
    Word pick(List<Answer> log, {required int atSecond, List<Word>? pool}) =>
        selectWord(
          pool: pool ?? all,
          stats: buildStats(log),
          recent: log,
          now: t0.add(Duration(seconds: atSecond)),
          random: Random(1),
        );

    test('starts with an unseen word', () {
      expect(pick([], atSecond: 0), isIn(all));
    });

    test('an overdue missed word beats a new word', () {
      final log = [
        answer('apple', 0, chosen: 'orange'),
        answer('cat', 10),
        answer('dog', 20),
        answer('cow', 30),
      ];
      expect(pick(log, atSecond: 60).id, 'apple');
    });

    test('does not repeat a word within the gap', () {
      final log = [answer('apple', 0, chosen: 'orange')];
      // apple is due (30 s box 0) but was just shown.
      expect(pick(log, atSecond: 60).id, isNot('apple'));
    });

    test('a known word is not due again the same day', () {
      final log = [for (var i = 0; i < 3; i++) answer('cat', i * 400)];
      final pool = [all.firstWhere((w) => w.id == 'cat'), word('new', 'x')];
      expect(pick(log, atSecond: 1200, pool: pool).id, 'new');
    });

    test('after two misses in a row it gives a known word', () {
      final log = [
        for (var i = 0; i < 3; i++) answer('cat', i * 400), // cat: box 3
        answer('apple', 1300, chosen: 'grape'),
        answer('orange', 1310, chosen: 'banana'),
        answer('grape', 1320, chosen: 'apple'),
      ];
      expect(pick(log, atSecond: 1400).id, 'cat');
    });

    test('never repeats a word already asked this round', () {
      // apple was missed and is overdue, but it was already asked.
      final log = [
        answer('apple', 0, chosen: 'orange'),
        answer('cat', 100),
        answer('dog', 110),
        answer('cow', 120),
      ];
      final w = selectWord(
        pool: all,
        stats: buildStats(log),
        recent: log,
        now: t0.add(const Duration(minutes: 10)),
        exclude: {'apple', 'cat', 'dog', 'cow'},
        random: Random(1),
      );
      expect(['apple', 'cat', 'dog', 'cow'], isNot(contains(w.id)));
    });

    test('a pool of one word still returns it', () {
      final pool = [all.first];
      final log = [answer(all.first.id, 0)];
      expect(pick(log, atSecond: 5, pool: pool), all.first);
    });
  });

  group('cardOrder', () {
    test('every word once, weakest first', () {
      final log = [
        answer('cat', 0), answer('cat', 400), // cat: box 2
        answer('dog', 10), // dog: box 1
        answer('cow', 20, chosen: 'pig'), // cow: box 0, missed
      ];
      final order = cardOrder(
        pool: animals.toList(),
        stats: buildStats(log),
        random: Random(4),
      ).map((w) => w.id).toList();

      expect(order.toSet(), hasLength(4));
      expect(order.first, 'cow');
      expect(order.last, 'cat');
      expect(order.indexOf('dog'), 2);
    });

    test('viewing a card does not push a word ahead of unseen ones', () {
      final log = [answer('cat', 0, activity: Activity.flashcard)];
      final order = cardOrder(
        pool: animals.toList(),
        stats: buildStats(log),
        random: Random(5),
      );
      expect(order.last.id, 'cat');
    });
  });

  group('pickDistractors', () {
    final apple = all.first;

    List<Word> options(List<Answer> log) => pickDistractors(
      target: apple,
      allWords: all,
      stats: buildStats(log),
      random: Random(2),
    );

    test('a weak word gets options from other categories', () {
      final opts = options([]);
      expect(opts, hasLength(3));
      expect(opts.every((w) => w.category != 'food'), isTrue);
    });

    test('a known word gets options from its own category', () {
      final opts = options([answer('apple', 0), answer('apple', 400)]);
      expect(opts.every((w) => w.category == 'food'), isTrue);
      expect(opts, isNot(contains(apple)));
    });

    test('past confusions come first', () {
      final opts = options([
        answer('apple', 0, chosen: 'cat'),
        answer('apple', 100),
        answer('apple', 500),
      ]);
      expect(opts.first.id, 'cat');
    });

    test('never returns the target or duplicates', () {
      final opts = pickDistractors(
        target: apple,
        allWords: all,
        stats: {},
        count: 7,
        random: Random(3),
      );
      expect(opts, hasLength(7));
      expect(opts.toSet(), hasLength(7));
      expect(opts, isNot(contains(apple)));
    });
  });
}
