import '../config.dart';
import '../l10n.dart';

/// [Answer.chosen] when the child picked nothing in time (a bubble floated
/// away). Counts as a miss, but not as confusing the word with another.
const timedOut = '_timeout';

/// One row of the append-only answer log. Rows are never updated or deleted;
/// per-word stats are derived from this log.
class Answer {
  final int? id;
  final String learnerId;
  final String activityType;
  final String wordId;

  /// The option the child picked (a word id), so specific confusions are kept.
  final String chosen;
  final bool correct;
  final int latencyMs;
  final DateTime timestamp;

  /// Language the word was asked in. Knowing "cat" is not knowing "gato",
  /// so progress is kept per language.
  final String language;

  const Answer({
    this.id,
    this.learnerId = defaultPlayer,
    required this.activityType,
    required this.wordId,
    required this.chosen,
    required this.correct,
    required this.latencyMs,
    required this.timestamp,
    this.language = defaultLanguage,
  });

  Map<String, Object?> toRow() => {
    'learner_id': learnerId,
    'activity_type': activityType,
    'word_id': wordId,
    'chosen': chosen,
    'correct': correct ? 1 : 0,
    'latency_ms': latencyMs,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'language': language,
  };

  factory Answer.fromRow(Map<String, Object?> row) => Answer(
    id: row['id'] as int,
    learnerId: row['learner_id'] as String,
    activityType: row['activity_type'] as String,
    wordId: row['word_id'] as String,
    chosen: row['chosen'] as String,
    correct: row['correct'] == 1,
    latencyMs: row['latency_ms'] as int,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    language: row['language'] as String? ?? defaultLanguage,
  );
}
