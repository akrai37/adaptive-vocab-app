import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n.dart';
import '../data/session.dart';
import '../data/speaker.dart';
import '../logic/explain.dart';
import '../logic/scoring.dart';
import '../models/activity.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/score.dart';
import '../widgets/why_note.dart';
import '../widgets/word_picture.dart';
import 'round_done_screen.dart';

/// Picture quiz: the app says a word, the child taps the matching picture out
/// of four. Only the first tap counts.
class QuizScreen extends StatefulWidget {
  final String category;
  final Session session;
  final Speaker speaker;

  const QuizScreen({
    super.key,
    required this.category,
    required this.session,
    required this.speaker,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String get _lang => widget.session.language;

  late Word _word;
  late List<Word> _options;

  /// Demo-mode notes for the current question (empty when demo mode is off).
  List<String> _why = const [];

  /// Words already asked this round; none is asked twice.
  final _asked = <String>{};
  final _timer = Stopwatch();
  Word? _tapped;
  int _done = 0;
  int _correct = 0;

  /// Whether this question's choices are hard (the child knows the word).
  bool _hard = false;
  int _points = 0;
  int _streak = 0;
  int _bestStreak = 0;

  /// Points from the last answer, shown as a pop-up until the next question.
  AnswerPoints? _gain;

  @override
  void initState() {
    super.initState();
    _show();
  }

  void _show() {
    final session = widget.session;
    final pick = session.nextPick(widget.category, askedThisRound: _asked);
    _word = pick.word;
    _asked.add(_word.id);
    _hard = session.isHard(_word);
    _options = session.optionsFor(_word);
    if (session.showWhy) {
      final s = session.stats[_word.id];
      final wrong = _options.where((w) => w.id != _word.id).toList();
      _why = [
        explainPick(pick, s, DateTime.now()),
        explainOptions(_word, wrong, s, _lang),
      ];
    }
    _tapped = null;
    _gain = null;
    _timer
      ..reset()
      ..start();
    widget.speaker.say(_word, _lang);
  }

  Future<void> _tap(Word chosen) async {
    if (_tapped != null) return;
    _timer.stop();
    final right = chosen.id == _word.id;
    _streak = right ? _streak + 1 : 0;
    if (_streak > _bestStreak) _bestStreak = _streak;
    final gain = scoreAnswer(
      correct: right,
      streak: _streak,
      latency: _timer.elapsed,
      hard: _hard,
    );
    setState(() {
      _tapped = chosen;
      _points += gain.total;
      _gain = right ? gain : null;
    });
    if (right) _correct++;
    await widget.session.record(
      activity: Activity.pictureQuiz,
      word: _word,
      chosen: chosen,
      latency: _timer.elapsed,
    );
    // A miss stays on screen longer so the child sees the right picture.
    await Future.delayed(Duration(milliseconds: right ? 800 : 2000));
    _done++;
    if (!mounted) return;
    if (_done == roundLength) {
      _points += pointsRoundDone;
      final outcome = await widget.session.finishRound(
        activity: Activity.pictureQuiz,
        category: widget.category,
        points: _points,
        correct: _correct,
        questions: roundLength,
        bestStreak: _bestStreak,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoundDoneScreen(
            texts: widget.session.texts,
            stars: starsFor(_correct),
            outcome: outcome,
            bestStreak: _bestStreak,
            playAgain: () => QuizScreen(
              category: widget.category,
              session: widget.session,
              speaker: widget.speaker,
            ),
          ),
        ),
      );
    } else {
      setState(_show);
    }
  }

  Color _colorFor(Word option) {
    if (_tapped == null) return Colors.white;
    if (option.id == _word.id) return const Color(0xFFB9F0C8);
    if (option == _tapped) return const Color(0xFFFFC2CC);
    return Colors.white;
  }

  Widget _optionButton(Word option) => BigTile(
    key: ValueKey(option.id),
    color: _colorFor(option),
    onTap: () => _tap(option),
    child: WordPicture(option, size: 130),
  );

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(widget.category);
    return Scaffold(
      appBar: AppBar(
        title: LinearProgressIndicator(
          value: _done / roundLength,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
        ),
        actions: [ScorePill(_points)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _word.label(_lang),
                  style: wordStyle(size: 64, color: color),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, size: 48, color: color),
                  tooltip: widget.session.texts.sayIt,
                  onPressed: () => widget.speaker.say(_word, _lang),
                ),
                if (_gain != null) ...[
                  const SizedBox(width: 16),
                  _GainPopup(
                    _gain!,
                    streak: _streak,
                    texts: widget.session.texts,
                  ),
                ],
              ],
            ),
          ),
          if (_why.isNotEmpty) WhyNote(_why),
          // 2×2 block that always fits the window, so no answer is off-screen.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    if (row > 0) const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 2; col++) ...[
                            if (col > 0) const SizedBox(width: 24),
                            Expanded(
                              child: _optionButton(_options[row * 2 + col]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+20 · 🔥 3 in a row!" after a right answer; pops in with a little bounce.
class _GainPopup extends StatelessWidget {
  final AnswerPoints gain;
  final int streak;
  final Texts texts;

  const _GainPopup(this.gain, {required this.streak, required this.texts});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.4, end: 1),
    duration: const Duration(milliseconds: 350),
    curve: Curves.elasticOut,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3CC46B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${gain.total}',
            key: const Key('gain'),
            style: wordStyle(size: 30, color: Colors.white),
          ),
          if (gain.hard > 0) ...[
            const SizedBox(width: 10),
            const Icon(Icons.bolt_rounded, color: gold),
            Text(texts.tricky, style: wordStyle(size: 20, color: Colors.white)),
          ],
          if (streak >= 2) ...[
            const SizedBox(width: 10),
            const Icon(Icons.local_fire_department_rounded, color: gold),
            Text(
              texts.inARow(streak),
              style: wordStyle(size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Stars out of 3 for a quiz round. Generous on purpose: finishing earns one.
int starsFor(int correct) => correct >= roundLength - 1
    ? 3
    : correct * 2 >= roundLength
    ? 2
    : 1;
