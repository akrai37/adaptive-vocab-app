import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/answer_log.dart';
import 'package:vocab_app/data/database.dart';
import 'package:vocab_app/data/learner_store.dart';
import 'package:vocab_app/data/session.dart';
import 'package:vocab_app/data/word_repository.dart';
import 'package:vocab_app/models/activity.dart';

void main() {
  sqfliteFfiInit();
  final words = WordRepository.fromJson(
    jsonDecode(File('content/words.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('each kid has their own words and progress', () async {
    final db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final log = AnswerLog(db);
    final store = LearnerStore(db);
    final mia = await store.add(name: 'Mia', avatar: 'cat');
    final leo = await store.add(name: 'Leo', avatar: 'dog');

    final miaSession = await Session.start(
      words: words,
      log: log,
      learnerId: mia.id,
    );
    final cat = words.byId('cat');
    await miaSession.record(
      activity: Activity.pictureQuiz,
      word: cat,
      chosen: words.byId('dog'),
      latency: const Duration(seconds: 2),
    );

    final leoSession = await Session.start(
      words: words,
      log: log,
      learnerId: leo.id,
    );
    expect(leoSession.stats, isEmpty);
    expect((await log.all(learnerId: mia.id)).single.wordId, 'cat');
    await db.close();
  });

  test('removing a kid keeps their answers', () async {
    final db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = LearnerStore(db);
    final mia = await store.add(name: '  Mia ', avatar: 'cat');
    expect(mia.name, 'Mia');
    final log = AnswerLog(db);
    final s = await Session.start(words: words, log: log, learnerId: mia.id);
    await s.record(
      activity: Activity.pictureQuiz,
      word: words.byId('cat'),
      chosen: words.byId('cat'),
      latency: const Duration(seconds: 1),
    );
    await store.remove(mia.id);
    expect(await store.all(), isEmpty);
    expect(await log.all(learnerId: mia.id), hasLength(1));
    await db.close();
  });

  test('upgrading a v1 database keeps old answers and adds kids', () async {
    final dir = await Directory.systemTemp.createTemp('vocab_db');
    final path = '${dir.path}/vocab.db';

    // A database as the previous app version left it.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE answers (
            id INTEGER PRIMARY KEY AUTOINCREMENT, learner_id TEXT NOT NULL,
            activity_type TEXT NOT NULL, word_id TEXT NOT NULL,
            chosen TEXT NOT NULL, correct INTEGER NOT NULL,
            latency_ms INTEGER NOT NULL, timestamp INTEGER NOT NULL)
        '''),
      ),
    );
    await v1.insert('answers', {
      'learner_id': 'anon',
      'activity_type': 'picture_quiz',
      'word_id': 'cat',
      'chosen': 'cat',
      'correct': 1,
      'latency_ms': 900,
      'timestamp': 0,
    });
    await v1.close();

    final db = await openAppDatabase(factory: databaseFactoryFfi, path: path);
    final old = await AnswerLog(db).all();
    expect(old, hasLength(1));
    expect(old.single.language, 'en', reason: 'answers before Spanish');
    await LearnerStore(db).add(name: 'Mia', avatar: 'cat');
    expect(await LearnerStore(db).all(), hasLength(1));
    await db.close();
    await dir.delete(recursive: true);
  });
}
