import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
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

/// Shows a picture, the word, and says it aloud. Pure exposure: nothing is
/// right or wrong, but each card is logged as "seen".
class FlashcardScreen extends StatefulWidget {
  final String category;
  final Session session;
  final Speaker speaker;

  const FlashcardScreen({
    super.key,
    required this.category,
    required this.session,
    required this.speaker,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  String get _lang => widget.session.language;

  /// Each word in the category once, weakest first.
  late final List<Word> _deck = widget.session.cardRound(widget.category);

  /// Demo-mode note per card, worked out before this round changes any stats.
  late final Map<String, String> _why = {
    for (final w in _deck) w.id: explainCard(widget.session.stats[w.id]),
  };
  late final int _total = min(roundLength, _deck.length);
  late Word _word;
  final _timer = Stopwatch();
  int _done = 0;

  /// True while a tap on Next is being saved, so a double-tap counts once.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _show();
  }

  void _show() {
    _word = _deck[_done];
    _timer
      ..reset()
      ..start();
    widget.speaker.sayWithFact(_word, _lang);
  }

  Future<void> _next() async {
    if (_busy) return;
    _busy = true;
    await widget.session.record(
      activity: Activity.flashcard,
      word: _word,
      chosen: _word,
      latency: _timer.elapsed,
    );
    _done++;
    if (!mounted) return;
    if (_done == _total) {
      final outcome = await widget.session.finishRound(
        activity: Activity.flashcard,
        category: widget.category,
        points: _total * pointsPerCard + pointsRoundDone,
        correct: 0,
        questions: _total,
        bestStreak: 0,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoundDoneScreen(
            texts: widget.session.texts,
            stars: 3,
            outcome: outcome,
            playAgain: () => FlashcardScreen(
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
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(widget.category);
    return Scaffold(
      appBar: AppBar(
        title: LinearProgressIndicator(
          value: _done / _total,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
        ),
        actions: [ScorePill(_done * pointsPerCard)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: BigTile(
                color: Colors.white,
                onTap: () => widget.speaker.say(_word, _lang),
                child: WordPicture(_word, size: 220),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.session.showWhy) WhyNote([_why[_word.id]!]),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _word.label(_lang),
                  style: wordStyle(size: 72, color: color),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, size: 52, color: color),
                  tooltip: widget.session.texts.sayIt,
                  onPressed: () => widget.speaker.sayWithFact(_word, _lang),
                ),
              ],
            ),
            if (_word.factIn(_lang) case final fact?) ...[
              const SizedBox(height: 12),
              _FactBubble(
                fact,
                color: color,
                onTap: () => widget.speaker.sayWithFact(_word, _lang),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        tooltip: widget.session.texts.next,
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: _next,
        child: const Icon(Icons.arrow_forward_rounded, size: 48),
      ),
    );
  }
}

/// "Did you know?" bubble with the word's fact.
class _FactBubble extends StatelessWidget {
  final String fact;
  final Color color;
  final VoidCallback onTap;

  const _FactBubble(this.fact, {required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 640),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_rounded, color: color, size: 36),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  fact,
                  key: const Key('fact'),
                  style: wordStyle(
                    size: 28,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
