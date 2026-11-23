import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Opens the app's single SQLite database. In the browser, SQLite runs as
/// WebAssembly and saves to the browser's storage.
///
/// Schema history:
///   v1  answers
///   v2  learners (kids picked on the "Who's playing?" screen)
///   v3  rounds (points per finished round)
///   v4  answers.language, player_settings (unused for now: the app always
///       opens in English)
Future<Database> openAppDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  final f = factory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
  final dbPath = path ?? p.join(await f.getDatabasesPath(), 'vocab.db');
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 4,
      onCreate: (db, _) async {
        await _createAnswers(db);
        await _createLearners(db);
        await _createRounds(db);
        await _createPlayerSettings(db);
      },
      onUpgrade: (db, from, _) async {
        if (from < 2) await _createLearners(db);
        if (from < 3) await _createRounds(db);
        if (from < 4) {
          await db.execute(
            "ALTER TABLE answers ADD COLUMN language TEXT NOT NULL DEFAULT 'en'",
          );
          await _createPlayerSettings(db);
        }
      },
    ),
  );
}

Future<void> _createAnswers(Database db) async {
  await db.execute('''
    CREATE TABLE answers (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      learner_id    TEXT    NOT NULL,
      activity_type TEXT    NOT NULL,
      word_id       TEXT    NOT NULL,
      chosen        TEXT    NOT NULL,
      correct       INTEGER NOT NULL,
      latency_ms    INTEGER NOT NULL,
      timestamp     INTEGER NOT NULL,
      language      TEXT    NOT NULL DEFAULT 'en'
    )
  ''');
  await db.execute(
    'CREATE INDEX answers_word ON answers (learner_id, word_id)',
  );
}

Future<void> _createLearners(Database db) => db.execute('''
  CREATE TABLE learners (
    id       TEXT    PRIMARY KEY,
    name     TEXT    NOT NULL,
    avatar   TEXT    NOT NULL,
    created  INTEGER NOT NULL
  )
''');

Future<void> _createRounds(Database db) => db.execute('''
  CREATE TABLE rounds (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    learner_id    TEXT    NOT NULL,
    activity_type TEXT    NOT NULL,
    category      TEXT    NOT NULL,
    points        INTEGER NOT NULL,
    correct       INTEGER NOT NULL,
    questions     INTEGER NOT NULL,
    best_streak   INTEGER NOT NULL,
    timestamp     INTEGER NOT NULL
  )
''');

Future<void> _createPlayerSettings(Database db) => db.execute('''
  CREATE TABLE player_settings (
    player_id  TEXT PRIMARY KEY,
    language   TEXT NOT NULL
  )
''');
