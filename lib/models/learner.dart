/// One child on the shared tablet. No password: a child picks their own
/// avatar on the "Who's playing?" screen. [id] is what the answer log stores
/// as learner_id.
class Learner {
  final String id;
  final String name;

  /// Word id whose picture is the child's avatar (e.g. "cat").
  final String avatar;
  final DateTime created;

  const Learner({
    required this.id,
    required this.name,
    required this.avatar,
    required this.created,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'created': created.millisecondsSinceEpoch,
  };

  factory Learner.fromRow(Map<String, Object?> row) => Learner(
    id: row['id'] as String,
    name: row['name'] as String,
    avatar: row['avatar'] as String,
    created: DateTime.fromMillisecondsSinceEpoch(row['created'] as int),
  );
}
