import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../models/answer.dart';
import 'database.dart';

/// Append-only log of every answer, stored in the app database.
class AnswerLog {
  final Database _db;

  AnswerLog(this._db);

  /// Opens the app database and wraps it. Mainly for tests; the app opens
  /// the database once and shares it.
  static Future<AnswerLog> open({
    DatabaseFactory? factory,
    String? path,
  }) async => AnswerLog(await openAppDatabase(factory: factory, path: path));

  Future<void> add(Answer answer) => _db.insert('answers', answer.toRow());

  /// All answers for [learnerId], oldest first.
  Future<List<Answer>> all({String learnerId = defaultPlayer}) async {
    final rows = await _db.query(
      'answers',
      where: 'learner_id = ?',
      whereArgs: [learnerId],
      orderBy: 'timestamp, id',
    );
    return rows.map(Answer.fromRow).toList();
  }

  Future<void> close() => _db.close();
}
