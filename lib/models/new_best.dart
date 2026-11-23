/// Sent out when a player beats their own best round in a game. Nothing in
/// this app listens to it; it is the hook for a host app to save the score
/// wherever it keeps scores.
class NewBest {
  final String playerId;

  /// Stable game key, e.g. `bubble_pop` (see `Activity.key`).
  final String game;

  /// Name children see, e.g. `Bubble Pop`.
  final String gameName;
  final int score;

  const NewBest({
    required this.playerId,
    required this.game,
    required this.gameName,
    required this.score,
  });

  @override
  String toString() => 'NewBest($playerId, $game, $score)';
}
