import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/answer_log.dart';
import 'package:vocab_app/data/database.dart';
import 'package:vocab_app/data/round_log.dart';
import 'package:vocab_app/data/session.dart';
import 'package:vocab_app/data/word_repository.dart';
import 'package:vocab_app/l10n.dart';
import 'package:vocab_app/models/activity.dart';

void main() {
  sqfliteFfiInit();
  final words = WordRepository.fromJson(
    jsonDecode(File('content/words.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  late Database db;
  setUp(
    () async => db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    ),
  );
  tearDown(() => db.close());

  Future<Session> start(String player, {String? language}) => Session.start(
    words: words,
    log: AnswerLog(db),
    rounds: RoundLog(db),
    learnerId: player,
    language: language,
  );

  Future<void> answerRight(Session s, String id, int n) async {
    final w = words.byId(id);
    for (var i = 0; i < n; i++) {
      await s.record(
        activity: Activity.pictureQuiz,
        word: w,
        chosen: w,
        latency: const Duration(seconds: 2),
        at: DateTime(2026, 11, 1, 10, i),
      );
    }
  }

  test('starts in English', () async {
    final s = await start('mia');
    expect(s.language, 'en');
    expect(s.texts.learnToday, 'What will you learn today?');
    expect(s.groupName('animals'), 'Animals');
  });

  test('knowing "cat" in English is not knowing "el gato"', () async {
    final s = await start('mia');
    await answerRight(s, 'cat', 3);
    expect(s.stats['cat']!.box, 3);
    expect(s.isHard(words.byId('cat')), isTrue);

    s.setLanguage('es');
    expect(s.stats['cat'], isNull, reason: 'new in Spanish');
    expect(s.isHard(words.byId('cat')), isFalse);
    await answerRight(s, 'cat', 1);
    expect(s.stats['cat']!.box, 1);

    s.setLanguage('en');
    expect(s.stats['cat']!.box, 3, reason: 'English progress kept');

    final saved = await AnswerLog(db).all(learnerId: 'mia');
    expect(saved.where((a) => a.language == 'en'), hasLength(3));
    expect(saved.where((a) => a.language == 'es'), hasLength(1));
  });

  test('the app always opens in English, even after Spanish', () async {
    final mia = await start('mia');
    mia.setLanguage('es');
    expect(mia.groupName('animals'), 'Animales');
    expect(mia.groupName('mix'), 'Todo mezclado');

    expect((await start('mia')).language, 'en', reason: 'after restart');
  });

  test('a host app can choose the starting language', () async {
    expect((await start('sam', language: 'es')).language, 'es');
    expect((await start('sam', language: 'xx')).language, 'en');
  });

  test('points and bests are one total per player, in any language', () async {
    final s = await start('mia');
    await s.finishRound(
      activity: Activity.pictureQuiz,
      category: 'animals',
      points: 70,
      correct: 7,
      questions: 8,
      bestStreak: 4,
    );
    s.setLanguage('es');
    expect(s.totalPoints, 70);
    expect(s.bestPoints(Activity.pictureQuiz), 70);
  });

  test('every screen text exists in both languages', () {
    final en = textsFor('en'), es = textsFor('es');
    expect(es.name, 'Español');
    expect(es.greatJob, isNot(en.greatJob));
    for (final a in Activity.values) {
      expect(es.game(a), isNotEmpty);
    }
    expect(es.game(Activity.bubblePop), isNot(en.game(Activity.bubblePop)));
  });
}
