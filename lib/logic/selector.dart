import 'dart:math';

import '../models/activity.dart';
import '../models/answer.dart';
import '../models/word.dart';
import 'stats.dart';

/// How long a word waits before it is due again, per Leitner box.
/// Box 0 and 1 come back within a session; higher boxes across days.
const intervals = [
  Duration(seconds: 30),
  Duration(minutes: 5),
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
];

/// A word is not repeated within this many answers, so a miss comes back
/// after a short gap instead of immediately.
const repeatGap = 3;

/// The child's "known" words: box at or above this.
const knownBox = 2;

/// Which rule in [pickWord] chose the word. Shown to teachers in demo mode.
enum PickReason {
  /// 2 of the last 3 graded answers were wrong, so a known word was given.
  struggling,

  /// The word's review interval had passed.
  overdue,

  /// The child had never seen the word.
  unseen,

  /// Nothing was due and every word had been seen; the closest to due.
  reviewAhead,
}

/// A chosen word plus the rule that chose it.
class Pick {
  final Word word;
  final PickReason reason;

  const Pick(this.word, this.reason);
}

/// The next word from [pool]; see [pickWord] for the rules.
Word selectWord({
  required List<Word> pool,
  required Map<String, WordStats> stats,
  required List<Answer> recent,
  required DateTime now,
  Set<String> exclude = const {},
  Random? random,
}) => pickWord(
  pool: pool,
  stats: stats,
  recent: recent,
  now: now,
  exclude: exclude,
  random: random,
).word;

/// Picks the next word from [pool] (usually one category).
///
/// [recent] is this learner's answers, oldest first; only the tail is used.
/// Order of preference:
///   1. If 2 of the last 3 graded answers were wrong, a known word, so a
///      session never turns into a run of failures.
///   2. The most overdue word.
///   3. A word the child has not seen yet.
///   4. The word closest to being due (review ahead).
/// Words in [exclude] (already asked this round) are never picked unless the
/// whole pool has been asked. Words from the last [repeatGap] answers are
/// skipped when possible.
Pick pickWord({
  required List<Word> pool,
  required Map<String, WordStats> stats,
  required List<Answer> recent,
  required DateTime now,
  Set<String> exclude = const {},
  Random? random,
}) {
  assert(pool.isNotEmpty);
  final rng = random ?? Random();

  final fresh = pool.where((w) => !exclude.contains(w.id)).toList();
  if (fresh.isNotEmpty) pool = fresh;

  final lastIds = recent.reversed.take(repeatGap).map((a) => a.wordId).toSet();
  var candidates = pool.where((w) => !lastIds.contains(w.id)).toList();
  if (candidates.isEmpty) {
    final last = recent.isEmpty ? null : recent.last.wordId;
    candidates = pool.where((w) => w.id != last).toList();
  }
  if (candidates.isEmpty) candidates = pool;

  final seen = candidates.where((w) => stats.containsKey(w.id)).toList();
  final unseen = candidates.where((w) => !stats.containsKey(w.id)).toList();

  if (_struggling(recent)) {
    final known = seen.where((w) => stats[w.id]!.box >= knownBox).toList();
    if (known.isNotEmpty) {
      return Pick(
        _best(known, (w) => stats[w.id]!.box.toDouble(), rng),
        PickReason.struggling,
      );
    }
  }

  double overdue(Word w) => _overdue(stats[w.id]!, now);

  final due = seen.where((w) => overdue(w) >= 1).toList();
  if (due.isNotEmpty) return Pick(_best(due, overdue, rng), PickReason.overdue);
  if (unseen.isNotEmpty) {
    return Pick(unseen[rng.nextInt(unseen.length)], PickReason.unseen);
  }
  return Pick(_best(seen, overdue, rng), PickReason.reviewAhead);
}

/// Order for a round of flashcards: every word in [pool] once, weakest first
/// (lowest box, then most missed, then longest since seen; never-seen words
/// count as longest). Flashcards are ungraded, so the spacing used by
/// [selectWord] would keep resurfacing the same few words.
List<Word> cardOrder({
  required List<Word> pool,
  required Map<String, WordStats> stats,
  Random? random,
}) {
  final shuffled = [...pool]..shuffle(random ?? Random());
  int lastSeen(Word w) => stats[w.id]?.lastSeen?.millisecondsSinceEpoch ?? 0;
  return shuffled..sort((a, b) {
    final sa = stats[a.id], sb = stats[b.id];
    final box = (sa?.box ?? 0).compareTo(sb?.box ?? 0);
    if (box != 0) return box;
    final missed = (sb?.missed ?? 0).compareTo(sa?.missed ?? 0);
    if (missed != 0) return missed;
    return lastSeen(a).compareTo(lastSeen(b));
  });
}

/// Wrong options for a multiple-choice question about [target].
///
/// This is the hidden difficulty dial. Weak words get options from other
/// categories (apple vs car, shoe, bird). Known words get options from the
/// same category, starting with words the child has confused with it before
/// (apple vs orange, grape, banana).
List<Word> pickDistractors({
  required Word target,
  required List<Word> allWords,
  required Map<String, WordStats> stats,
  int count = 3,
  Random? random,
}) {
  final rng = random ?? Random();
  final s = stats[target.id];
  final hard = s != null && s.box >= knownBox;

  final others = allWords.where((w) => w.id != target.id).toList()
    ..shuffle(rng);
  final picked = <Word>[];
  void addFrom(Iterable<Word> source) {
    for (final w in source) {
      if (picked.length == count) return;
      if (!picked.contains(w)) picked.add(w);
    }
  }

  if (hard) {
    final confused = s.confusions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    addFrom(
      confused.map((e) => others.where((w) => w.id == e.key)).expand((w) => w),
    );
    addFrom(others.where((w) => w.category == target.category));
  } else {
    addFrom(others.where((w) => w.category != target.category));
  }
  addFrom(others);
  return picked;
}

bool _struggling(List<Answer> recent) {
  final graded = recent.reversed
      .where((a) => Activity.fromKey(a.activityType).graded)
      .take(3)
      .toList();
  return graded.where((a) => !a.correct).length >= 2;
}

/// Time since last seen, as a fraction of the box's interval. 1.0 = just due.
double _overdue(WordStats s, DateTime now) {
  final elapsed = now.difference(s.lastSeen!).inMilliseconds;
  return elapsed / intervals[s.box].inMilliseconds;
}

/// Highest-scoring word; ties broken at random so order does not look fixed.
Word _best(List<Word> words, double Function(Word) score, Random rng) {
  final top = words.map(score).reduce(max);
  final ties = words.where((w) => score(w) == top).toList();
  return ties[rng.nextInt(ties.length)];
}
