import '../models/activity.dart';
import '../models/answer.dart';

/// Highest Leitner box. A word reaches it after this many correct answers in a
/// row.
const maxBox = 4;

/// Per-word summary for one learner, derived entirely from the answer log.
class WordStats {
  final String wordId;
  int shown = 0;

  /// Answers that were right/wrong (excludes flashcards).
  int graded = 0;
  int missed = 0;

  /// Correct graded answers in a row. A wrong answer resets it to 0.
  int streak = 0;
  DateTime? lastSeen;

  /// Wrong options picked for this word, with counts (e.g. apple → orange: 2).
  final Map<String, int> confusions = {};

  WordStats(this.wordId);

  /// Leitner box, 0 (weak) to [maxBox] (strong).
  int get box => streak > maxBox ? maxBox : streak;
}

/// Rolls an answer log (oldest first) into stats keyed by word id.
Map<String, WordStats> buildStats(Iterable<Answer> answers) {
  final stats = <String, WordStats>{};
  for (final a in answers) {
    final s = stats.putIfAbsent(a.wordId, () => WordStats(a.wordId));
    s.shown++;
    s.lastSeen = a.timestamp;
    if (!Activity.fromKey(a.activityType).graded) continue;
    s.graded++;
    if (a.correct) {
      s.streak++;
    } else {
      s.missed++;
      s.streak = 0;
      if (a.chosen != timedOut) {
        s.confusions.update(a.chosen, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  return stats;
}
