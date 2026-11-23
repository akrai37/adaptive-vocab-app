import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/config.dart';
import 'package:vocab_app/data/answer_log.dart';
import 'package:vocab_app/data/database.dart';
import 'package:vocab_app/data/round_log.dart';
import 'package:vocab_app/data/session.dart';
import 'package:vocab_app/data/word_repository.dart';
import 'package:vocab_app/logic/scoring.dart';
import 'package:vocab_app/models/activity.dart';
import 'package:vocab_app/models/new_best.dart';

void main() {
  group('scoreAnswer', () {
    const slow = Duration(seconds: 5), quick = Duration(seconds: 1);

    test('wrong answers score nothing and never subtract', () {
      final p = scoreAnswer(
        correct: false,
        streak: 0,
        latency: quick,
        hard: true,
      );
      expect(p.total, 0);
    });

    test('plain right answer', () {
      final p = scoreAnswer(
        correct: true,
        streak: 1,
        latency: slow,
        hard: false,
      );
      expect(p.total, pointsCorrect);
    });

    test('fast, hard, and streak bonuses add up', () {
      final p = scoreAnswer(
        correct: true,
        streak: 3,
        latency: quick,
        hard: true,
      );
      expect(p.base, 10);
      expect(p.fast, 5);
      expect(p.hard, 5);
      expect(p.streak, 10);
      expect(p.total, 30);
    });

    test('streak bonus is capped', () {
      expect(streakBonus(1), 0);
      expect(streakBonus(2), 5);
      expect(streakBonus(3), 10);
      expect(streakBonus(4), 15);
      expect(streakBonus(20), 15);
    });
  });

  group('levels', () {
    test('thresholds grow each level', () {
      expect([1, 2, 3, 4, 5].map(levelStart), [0, 100, 300, 600, 1000]);
    });

    test('levelFor and progress', () {
      expect(levelFor(0), 1);
      expect(levelFor(99), 1);
      expect(levelFor(100), 2);
      expect(levelFor(299), 2);
      expect(levelFor(300), 3);
      expect(levelProgress(200), closeTo(0.5, 1e-9));
    });
  });

  group('session points', () {
    sqfliteFfiInit();
    final words = WordRepository.fromJson(
      jsonDecode(File('content/words.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test(
      'rounds add up, best and level-up are reported, and survive restart',
      () async {
        final db = await openAppDatabase(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );
        final log = AnswerLog(db), rounds = RoundLog(db);
        final s = await Session.start(words: words, log: log, rounds: rounds);
        expect(s.totalPoints, 0);
        expect(s.level, 1);

        final first = await s.finishRound(
          activity: Activity.pictureQuiz,
          category: 'animals',
          points: 80,
          correct: 6,
          questions: 8,
          bestStreak: 3,
        );
        expect(first.newBest, isTrue);
        expect(first.levelUp, isFalse);

        final cards = await s.finishRound(
          activity: Activity.flashcard,
          category: 'animals',
          points: 36,
          correct: 0,
          questions: 8,
          bestStreak: 0,
        );
        expect(cards.newBest, isFalse, reason: 'best is for Find it rounds');
        expect(cards.levelUp, isTrue, reason: '80 + 36 crosses 100');
        expect(cards.totalPoints, 116);

        final worse = await s.finishRound(
          activity: Activity.pictureQuiz,
          category: 'food',
          points: 50,
          correct: 4,
          questions: 8,
          bestStreak: 1,
        );
        expect(worse.newBest, isFalse);
        expect(worse.best, 80);

        // A fresh session (app restart) reads the saved rounds back.
        final again = await Session.start(
          words: words,
          log: log,
          rounds: rounds,
        );
        expect(again.totalPoints, 166);
        expect(again.bestPoints(Activity.pictureQuiz), 80);
        expect(again.level, 2);
        await db.close();
      },
    );

    test('each player has their own bests, and only a beaten best is '
        'reported', () async {
      final db = await openAppDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final log = AnswerLog(db), rounds = RoundLog(db);
      final reported = <NewBest>[];
      Future<Session> player(String id) => Session.start(
        words: words,
        log: log,
        rounds: rounds,
        learnerId: id,
        onNewBest: reported.add,
      );
      Future<void> play(Session s, Activity game, int points) => s.finishRound(
        activity: game,
        category: 'animals',
        points: points,
        correct: 0,
        questions: 8,
        bestStreak: 0,
      );

      final mia = await player('mia');
      await play(mia, Activity.bubblePop, 90);
      await play(mia, Activity.bubblePop, 60); // not a best
      await play(mia, Activity.flashcard, 36); // cards have no best
      await play(mia, Activity.bubblePop, 120);
      expect(reported.map((b) => '${b.playerId} ${b.game} ${b.score}'), [
        'mia bubble_pop 90',
        'mia bubble_pop 120',
      ]);

      final sam = await player('sam');
      expect(sam.bestPoints(Activity.bubblePop), 0, reason: "not Mia's");
      expect(sam.totalPoints, 0);
      await play(sam, Activity.bubblePop, 50);
      expect(reported.last.playerId, 'sam');
      expect(reported.last.score, 50, reason: "Sam's own first best");

      final miaAgain = await player('mia');
      expect(miaAgain.bestPoints(Activity.bubblePop), 120);
      await db.close();
    });

    test('a broken listener does not break the game', () async {
      final db = await openAppDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final s = await Session.start(
        words: words,
        log: AnswerLog(db),
        rounds: RoundLog(db),
        onNewBest: (_) => throw StateError('host is down'),
      );
      final out = await s.finishRound(
        activity: Activity.pictureQuiz,
        category: 'food',
        points: 40,
        correct: 4,
        questions: 8,
        bestStreak: 2,
      );
      expect(out.newBest, isTrue);
      expect(s.bestPoints(Activity.pictureQuiz), 40);
      await db.close();
    });

    test('teacher reset clears points and bests for everyone, keeps '
        'learning', () async {
      final db = await openAppDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final log = AnswerLog(db), rounds = RoundLog(db);
      Future<Session> player(String id) =>
          Session.start(words: words, log: log, rounds: rounds, learnerId: id);
      final cat = words.byId('cat');
      for (final id in ['mia', 'sam']) {
        final s = await player(id);
        await s.record(
          activity: Activity.pictureQuiz,
          word: cat,
          chosen: cat,
          latency: const Duration(seconds: 1),
        );
        await s.finishRound(
          activity: Activity.pictureQuiz,
          category: 'animals',
          points: 90,
          correct: 8,
          questions: 8,
          bestStreak: 8,
        );
      }

      final mia = await player('mia');
      await mia.resetAllPoints();
      expect(mia.totalPoints, 0);
      expect(mia.bestPoints(Activity.pictureQuiz), 0);

      final sam = await player('sam');
      expect(sam.totalPoints, 0, reason: 'everyone, not just Mia');
      expect(sam.level, 1);
      expect(sam.stats['cat']!.box, 1, reason: 'learning is kept');
      await db.close();
    });

    test('which games keep a best, and which are graded', () {
      expect(Activity.flashcard.hasBest, isFalse);
      expect(Activity.memoryMatch.hasBest, isTrue);
      expect(Activity.memoryMatch.graded, isFalse, reason: 'flips are memory');
      expect(Activity.pictureQuiz.graded && Activity.bubblePop.graded, isTrue);
    });

    test('memory rounds use different words from the group', () async {
      final db = await openAppDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final s = await Session.start(words: words, log: AnswerLog(db));
      final picked = s.memoryWords('sea');
      expect(picked, hasLength(6));
      expect(picked.map((w) => w.id).toSet(), hasLength(6));
      expect(picked.every((w) => w.category == 'sea'), isTrue);
      await db.close();
    });

    test('mix pool has words from every group', () {
      final groups = words.pool(mixCategory).map((w) => w.category).toSet();
      expect(groups, words.categories.toSet());
    });
  });
}
