import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/logic/explain.dart';
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

final t0 = DateTime(2026, 11, 9, 9);

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

  Pick pick(List<Answer> log, int atSecond) => pickWord(
    pool: all,
    stats: buildStats(log),
    recent: log,
    now: t0.add(Duration(seconds: atSecond)),
    random: Random(1),
  );

  group('pickWord reasons', () {
    test('new word', () {
      final p = pick([], 0);
      expect(p.reason, PickReason.unseen);
      expect(explainPick(p, null, t0), 'New word');
    });

    test('missed word brought back', () {
      final log = [
        answer('apple', 0, chosen: 'orange'),
        answer('cat', 10),
        answer('dog', 20),
        answer('cow', 30),
      ];
      final p = pick(log, 120);
      expect(p.word.id, 'apple');
      expect(p.reason, PickReason.overdue);
      final s = buildStats(log)['apple'];
      expect(
        explainPick(p, s, t0.add(const Duration(seconds: 120))),
        'Brought back: missed 2 min ago',
      );
    });

    test('easy one after misses', () {
      final log = [
        for (var i = 0; i < 3; i++) answer('cat', i * 400),
        answer('apple', 1300, chosen: 'grape'),
        answer('orange', 1310, chosen: 'banana'),
        answer('grape', 1320, chosen: 'apple'),
      ];
      final p = pick(log, 1400);
      expect(p.reason, PickReason.struggling);
      expect(explainPick(p, null, t0), startsWith('Easy one'));
    });

    test('word only seen in Cards', () {
      final log = [answer('apple', 0, activity: Activity.flashcard)];
      final p = pickWord(
        pool: [all.first],
        stats: buildStats(log),
        recent: const [],
        now: t0.add(const Duration(minutes: 3)),
      );
      expect(
        explainPick(
          p,
          buildStats(log)['apple'],
          t0.add(const Duration(minutes: 3)),
        ),
        'Practise it: seen (Cards or Memory) 3 min ago',
      );
    });
  });

  group('explainOptions', () {
    final apple = all.first;

    test('weak word gets easy choices', () {
      expect(
        explainOptions(apple, [all[5]], null, 'en'),
        'Easy choices: from other groups (box 0)',
      );
    });

    test('known word names past mix-ups', () {
      final s = buildStats([
        answer('apple', 0, chosen: 'orange'),
        answer('apple', 100),
        answer('apple', 500),
      ])['apple'];
      final orange = all[1], grape = all[2];
      expect(
        explainOptions(apple, [orange, grape], s, 'en'),
        'Hard choices: same group (box 2), includes past mix-up: orange',
      );
    });
  });

  group('explainCard', () {
    test('covers each case', () {
      expect(explainCard(null), 'Not seen yet');
      final missed = buildStats([answer('cat', 0, chosen: 'dog')])['cat'];
      expect(explainCard(missed), 'Shown early: missed 1 time');
      final known = buildStats([answer('cat', 0), answer('cat', 400)])['cat'];
      expect(explainCard(known), 'Known well (box 2), so shown late');
    });
  });

  test('ago', () {
    expect(ago(const Duration(seconds: 40)), '40 s');
    expect(ago(const Duration(minutes: 3)), '3 min');
    expect(ago(const Duration(hours: 5)), '5 h');
    expect(ago(const Duration(days: 3)), '3 days');
  });
}
