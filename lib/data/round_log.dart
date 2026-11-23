import 'package:sqflite/sqflite.dart';

import '../models/round_result.dart';

/// Finished rounds, for total points and personal bests.
class RoundLog {
  final Database _db;

  RoundLog(this._db);

  Future<void> add(RoundResult round) => _db.insert('rounds', round.toRow());

  /// Deletes every finished round, for every child: all points and bests go
  /// back to 0. What children have learned (the answer log) is kept.
  Future<void> clearAll() => _db.delete('rounds');

  Future<int> totalPoints(String learnerId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(points), 0) AS n FROM rounds WHERE learner_id = ?',
      [learnerId],
    );
    return rows.first['n'] as int;
  }

  /// Best points in one round of [activityType], or 0 if never played.
  Future<int> bestPoints(String learnerId, String activityType) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(points), 0) AS n FROM rounds '
      'WHERE learner_id = ? AND activity_type = ?',
      [learnerId, activityType],
    );
    return rows.first['n'] as int;
  }
}
