import 'models/activity.dart';

/// Languages children can switch between, by code (same codes as the main
/// app: "en", "es"). Words and facts live in `content/words.json`; the text on
/// screens lives here.
const languages = ['en', 'es'];
const defaultLanguage = 'en';

/// Text-to-speech voice per language. Latin American Spanish.
const ttsLocale = {'en': 'en-US', 'es': 'es-MX'};

/// Everything a child reads on screen, in one language. Teacher-only screens
/// stay in English.
abstract class Texts {
  const Texts();

  /// The language's own name, for the switch: "English", "Español".
  String get name;
  String get learnToday;
  String hi(String name);
  String get mixEverything;
  String game(Activity a);
  String best(String game, int points);
  String level(int n);
  String levelLine(int points, int toNext, int nextLevel);
  String get sayIt;
  String get next;
  String get tricky;
  String inARow(int n);
  String get greatJob;
  String plusPoints(int n);
  String get newBest;
  String levelUp(int n);
  String get again;
  String get home;
  String get exit;
}

Texts textsFor(String lang) => lang == 'es' ? const _Es() : const _En();

class _En extends Texts {
  const _En();

  @override
  String get name => 'English';
  @override
  String get learnToday => 'What will you learn today?';
  @override
  String hi(String name) => 'Hi $name! What will you learn today?';
  @override
  String get mixEverything => 'Mix everything';
  @override
  String game(Activity a) => a.label;
  @override
  String best(String game, int points) => 'Best $game: $points';
  @override
  String level(int n) => 'Level $n';
  @override
  String levelLine(int points, int toNext, int nextLevel) =>
      '$points points · $toNext to level $nextLevel';
  @override
  String get sayIt => 'Say it';
  @override
  String get next => 'Next';
  @override
  String get tricky => 'Tricky!';
  @override
  String inARow(int n) => '$n in a row!';
  @override
  String get greatJob => 'Great job!';
  @override
  String plusPoints(int n) => '+$n points';
  @override
  String get newBest => 'New best!';
  @override
  String levelUp(int n) => 'Level up! Level $n';
  @override
  String get again => 'Again';
  @override
  String get home => 'Home';
  @override
  String get exit => 'Exit';
}

class _Es extends Texts {
  const _Es();

  @override
  String get name => 'Español';
  @override
  String get learnToday => '¿Qué vas a aprender hoy?';
  @override
  String hi(String name) => '¡Hola, $name! ¿Qué vas a aprender hoy?';
  @override
  String get mixEverything => 'Todo mezclado';
  @override
  String game(Activity a) => switch (a) {
    Activity.flashcard => 'Tarjetas',
    Activity.pictureQuiz => 'Encuéntralo',
    Activity.bubblePop => 'Burbujas',
    Activity.memoryMatch => 'Memorama',
    Activity.spelling => 'Deletrear',
  };
  @override
  String best(String game, int points) => 'Récord en $game: $points';
  @override
  String level(int n) => 'Nivel $n';
  @override
  String levelLine(int points, int toNext, int nextLevel) =>
      '$points puntos · faltan $toNext para el nivel $nextLevel';
  @override
  String get sayIt => 'Escuchar';
  @override
  String get next => 'Siguiente';
  @override
  String get tricky => '¡Difícil!';
  @override
  String inARow(int n) => '¡$n seguidas!';
  @override
  String get greatJob => '¡Muy bien!';
  @override
  String plusPoints(int n) => '+$n puntos';
  @override
  String get newBest => '¡Nuevo récord!';
  @override
  String levelUp(int n) => '¡Subiste al nivel $n!';
  @override
  String get again => 'Otra vez';
  @override
  String get home => 'Inicio';
  @override
  String get exit => 'Salir';
}
