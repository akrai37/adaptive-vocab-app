import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../l10n.dart';
import '../logic/scoring.dart';
import '../logic/selector.dart';
import '../logic/stats.dart';
import '../models/activity.dart';
import '../models/answer.dart';
import '../models/new_best.dart';
import '../models/round_result.dart';
import '../models/word.dart';
import 'answer_log.dart';
import 'round_log.dart';
import 'word_repository.dart';

/// What a finished round changed, for the end-of-round screen.
class RoundOutcome {
  final int points;
  final int totalPoints;
  final int levelBefore;
  final int levelAfter;

  /// True if this beat the child's previous best round of the same game.
  final bool newBest;
  final int best;

  const RoundOutcome({
    required this.points,
    required this.totalPoints,
    required this.levelBefore,
    required this.levelAfter,
    required this.newBest,
    required this.best,
  });

  bool get levelUp => levelAfter > levelBefore;
}

/// Connects the pure selector to storage for one learner: keeps the answer
/// history in memory, writes every answer to the log, and hands out questions.
/// Notifies listeners when points change, so screens showing them redraw.
class Session extends ChangeNotifier {
  final WordRepository words;
  final AnswerLog log;

  /// Where finished rounds are saved; null keeps points in memory only.
  final RoundLog? rounds;
  final String learnerId;
  final Random _rng;
  final List<Answer> _history;
  Map<String, WordStats> _stats;
  int _totalPoints;

  /// Best points in one round, per game with right/wrong answers.
  final Map<Activity, int> _best;

  /// Called when this player beats their best in a game. For a host app.
  final void Function(NewBest best)? onNewBest;

  String _language;

  Session._(
    this.words,
    this.log,
    this.rounds,
    this.learnerId,
    this._rng,
    this._history,
    this._totalPoints,
    this._best,
    this.onNewBest,
    this._language,
  ) : _stats = {} {
    _stats = buildStats(_inLanguage);
  }

  static Future<Session> start({
    required WordRepository words,
    required AnswerLog log,
    RoundLog? rounds,
    String learnerId = defaultPlayer,
    Random? random,
    void Function(NewBest best)? onNewBest,

    /// Starts in this language (e.g. chosen by a host app), else English.
    /// The app always opens in English; children switch on the home screen.
    String? language,
  }) async {
    final history = await log.all(learnerId: learnerId);
    final lang = languages.contains(language) ? language! : defaultLanguage;
    return Session._(
      words,
      log,
      rounds,
      learnerId,
      random ?? Random(),
      history,
      await rounds?.totalPoints(learnerId) ?? 0,
      {
        for (final a in Activity.values.where((a) => a.hasBest))
          a: await rounds?.bestPoints(learnerId, a.key) ?? 0,
      },
      onNewBest,
      lang,
    );
  }

  /// Teacher reset: points, levels and bests back to 0 for every child.
  /// Word progress is kept.
  Future<void> resetAllPoints() async {
    await rounds?.clearAll();
    _totalPoints = 0;
    _best.updateAll((_, _) => 0);
    notifyListeners();
  }

  /// Language the child is learning in right now ("en" or "es").
  String get language => _language;

  /// Text on screens, in [language].
  Texts get texts => textsFor(_language);

  /// Switches language. Word progress is kept per language, so the adaptive
  /// order starts from what the child knows in that language.
  void setLanguage(String lang) {
    if (lang == _language || !languages.contains(lang)) return;
    _language = lang;
    _stats = buildStats(_inLanguage);
    notifyListeners();
  }

  /// What a child sees for [category], including "Mix everything".
  String groupName(String category) => category == mixCategory
      ? texts.mixEverything
      : words.categoryName(category, _language);

  /// Answers given in the current language, oldest first.
  List<Answer> get _inLanguage =>
      _history.where((a) => a.language == _language).toList();

  Map<String, WordStats> get stats => _stats;

  int get totalPoints => _totalPoints;
  int get level => levelFor(_totalPoints);

  /// Best points in one round of [activity] so far (0 if never played).
  int bestPoints(Activity activity) => _best[activity] ?? 0;

  /// Whether [word]'s choices will be hard (same group): the child already
  /// knows it. Hard questions are worth more.
  bool isHard(Word word) => (_stats[word.id]?.box ?? 0) >= knownBox;

  /// Demo mode: when on, games show why each word and its choices were
  /// picked. Teacher-only, off by default, not saved between launches.
  bool showWhy = false;

  /// The next word to practise from [category], and why it was chosen,
  /// skipping words already asked this round ([askedThisRound]).
  Pick nextPick(
    String category, {
    Set<String> askedThisRound = const {},
    DateTime? now,
  }) => pickWord(
    pool: words.pool(category),
    stats: _stats,
    recent: _inLanguage,
    now: now ?? DateTime.now(),
    exclude: askedThisRound,
    random: _rng,
  );

  /// The words for one round of flashcards from [category], weakest first.
  List<Word> cardRound(String category) =>
      cardOrder(pool: words.pool(category), stats: _stats, random: _rng);

  /// [count] different words for a Memory round from [category], chosen by
  /// the same adaptive order as the quiz (struggling, due, new, then ahead).
  List<Word> memoryWords(String category, {int count = memoryPairs}) {
    final picked = <Word>[];
    final ids = <String>{};
    final n = min(count, words.pool(category).length);
    while (picked.length < n) {
      final w = nextPick(category, askedThisRound: ids).word;
      picked.add(w);
      ids.add(w.id);
    }
    return picked;
  }

  /// [target] plus [count] wrong options, shuffled.
  List<Word> optionsFor(Word target, {int count = 3}) => [
    target,
    ...pickDistractors(
      target: target,
      allWords: words.words,
      stats: _stats,
      count: count,
      random: _rng,
    ),
  ]..shuffle(_rng);

  /// Logs one answer. A null [chosen] means nothing was picked in time.
  Future<void> record({
    required Activity activity,
    required Word word,
    required Word? chosen,
    required Duration latency,
    DateTime? at,
  }) async {
    final answer = Answer(
      learnerId: learnerId,
      activityType: activity.key,
      wordId: word.id,
      chosen: chosen?.id ?? timedOut,
      correct: chosen?.id == word.id,
      latencyMs: latency.inMilliseconds,
      timestamp: at ?? DateTime.now(),
      language: _language,
    );
    _history.add(answer);
    _stats = buildStats(_inLanguage);
    await log.add(answer);
  }

  /// Saves a finished round and adds its points to the child's total.
  Future<RoundOutcome> finishRound({
    required Activity activity,
    required String category,
    required int points,
    required int correct,
    required int questions,
    required int bestStreak,
    DateTime? at,
  }) async {
    final levelBefore = level;
    final newBest = activity.hasBest && points > bestPoints(activity);
    _totalPoints += points;
    if (newBest) _best[activity] = points;
    await rounds?.add(
      RoundResult(
        learnerId: learnerId,
        activityType: activity.key,
        category: category,
        points: points,
        correct: correct,
        questions: questions,
        bestStreak: bestStreak,
        timestamp: at ?? DateTime.now(),
      ),
    );
    notifyListeners();
    if (newBest) _reportBest(activity, points);
    return RoundOutcome(
      points: points,
      totalPoints: _totalPoints,
      levelBefore: levelBefore,
      levelAfter: level,
      newBest: newBest,
      best: bestPoints(activity),
    );
  }

  /// A broken listener must never break the game, so errors are only logged.
  void _reportBest(Activity activity, int points) {
    try {
      onNewBest?.call(
        NewBest(
          playerId: learnerId,
          game: activity.key,
          gameName: activity.label,
          score: points,
        ),
      );
    } catch (e) {
      debugPrint('onNewBest failed: $e');
    }
  }
}
