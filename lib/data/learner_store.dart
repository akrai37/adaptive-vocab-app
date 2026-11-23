import 'package:sqflite/sqflite.dart';

import '../models/learner.dart';

/// The children set up on this tablet.
class LearnerStore {
  final Database _db;

  LearnerStore(this._db);

  /// All children, oldest first, so tiles keep their place on screen.
  Future<List<Learner>> all() async {
    final rows = await _db.query('learners', orderBy: 'created, id');
    return rows.map(Learner.fromRow).toList();
  }

  Future<Learner> add({
    required String name,
    required String avatar,
    DateTime? now,
  }) async {
    final created = now ?? DateTime.now();
    final learner = Learner(
      id: 'kid-${created.microsecondsSinceEpoch}',
      name: name.trim(),
      avatar: avatar,
      created: created,
    );
    await _db.insert('learners', learner.toRow());
    return learner;
  }

  /// Removes the child from the picker. Their answers stay in the log.
  Future<void> remove(String id) =>
      _db.delete('learners', where: 'id = ?', whereArgs: [id]);
}
