import '../config.dart';

/// One finished round of a game, for points and personal bests.
class RoundResult {
  final String learnerId;
  final String activityType;
  final String category;
  final int points;
  final int correct;
  final int questions;
  final int bestStreak;
  final DateTime timestamp;

  const RoundResult({
    this.learnerId = defaultPlayer,
    required this.activityType,
    required this.category,
    required this.points,
    required this.correct,
    required this.questions,
    required this.bestStreak,
    required this.timestamp,
  });

  Map<String, Object?> toRow() => {
    'learner_id': learnerId,
    'activity_type': activityType,
    'category': category,
    'points': points,
    'correct': correct,
    'questions': questions,
    'best_streak': bestStreak,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}
