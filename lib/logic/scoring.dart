/// Points, streaks and levels. Personal progress only: points are never
/// taken away, and children are never ranked against each other.
library;

import 'dart:math';

const pointsCorrect = 10;

/// Extra for a right answer when the choices were hard (same group), i.e. the
/// adaptive engine had judged the word as known. Harder questions pay more.
const pointsHard = 5;

/// Extra for a right answer faster than [fastAnswer].
const pointsFast = 5;
const fastAnswer = Duration(seconds: 3);

/// Per card viewed in Cards (learning counts too).
const pointsPerCard = 2;

/// For finishing any round.
const pointsRoundDone = 20;

/// Extra for answers in a row: 2 → +5, 3 → +10, 4 or more → +15.
int streakBonus(int streak) => streak < 2 ? 0 : min((streak - 1) * 5, 15);

/// Points for one Find it answer, split into parts so the screen can show
/// where they came from.
class AnswerPoints {
  final int base;
  final int hard;
  final int fast;
  final int streak;

  const AnswerPoints({
    this.base = 0,
    this.hard = 0,
    this.fast = 0,
    this.streak = 0,
  });

  int get total => base + hard + fast + streak;
}

/// [streak] is the number of right answers in a row including this one.
AnswerPoints scoreAnswer({
  required bool correct,
  required int streak,
  required Duration latency,
  required bool hard,
}) {
  if (!correct) return const AnswerPoints();
  return AnswerPoints(
    base: pointsCorrect,
    hard: hard ? pointsHard : 0,
    fast: latency < fastAnswer ? pointsFast : 0,
    streak: streakBonus(streak),
  );
}

/// Points needed to reach [level] (level 1 starts at 0): 0, 100, 300, 600,
/// 1000, … Each level takes a little longer than the last.
int levelStart(int level) => 50 * level * (level - 1);

/// The level a child with [totalPoints] is on.
int levelFor(int totalPoints) {
  var level = 1;
  while (levelStart(level + 1) <= totalPoints) {
    level++;
  }
  return level;
}

/// How far through their current level, from 0.0 to just under 1.0.
double levelProgress(int totalPoints) {
  final level = levelFor(totalPoints);
  final from = levelStart(level), to = levelStart(level + 1);
  return (totalPoints - from) / (to - from);
}
