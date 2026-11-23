/// The games a child can pick. [key] is what gets written to the answer log.
enum Activity {
  flashcard('flashcard', 'Cards', graded: false),
  pictureQuiz('picture_quiz', 'Find it'),
  bubblePop('bubble_pop', 'Bubble Pop'),
  memoryMatch('memory_match', 'Flip & Match', graded: false),
  spelling('spelling', 'Spelling');

  final String key;

  /// Name children see.
  final String label;

  /// Whether answers in this activity are right/wrong. Flashcards are only
  /// exposure: they count as "seen" but never move a word up or down.
  final bool graded;

  /// Whether rounds keep a personal best: only games where every answer
  /// tests the word. Cards and Flip & Match are practice, so their rounds
  /// score a fixed amount and keep no best.
  final bool hasBest;

  const Activity(this.key, this.label, {this.graded = true, bool? hasBest})
    : hasBest = hasBest ?? graded;

  static Activity fromKey(String key) => values.firstWhere((a) => a.key == key);
}
