import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
import '../data/session.dart';
import '../data/speaker.dart';
import '../logic/scoring.dart';
import '../models/activity.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/score.dart';
import '../widgets/word_picture.dart';
import 'round_done_screen.dart';

/// Memory game: cards lie face down, half pictures and half words. Flip two;
/// a picture and its word stay open. Words come from the adaptive engine.
/// A found pair is logged as practice (like Cards): a wrong flip is usually
/// a memory slip, not a vocabulary mistake, so it never counts against a word.
class MemoryMatchScreen extends StatefulWidget {
  final String category;
  final Session session;
  final Speaker speaker;

  const MemoryMatchScreen({
    super.key,
    required this.category,
    required this.session,
    required this.speaker,
  });

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _Card {
  final Word word;
  final bool picture;

  const _Card(this.word, {required this.picture});

  String get id => '${picture ? 'pic' : 'word'}-${word.id}';
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  String get _lang => widget.session.language;

  late final List<Word> _words = widget.session.memoryWords(widget.category);
  late final List<_Card> _cards = [
    for (final w in _words) ...[
      _Card(w, picture: true),
      _Card(w, picture: false),
    ],
  ]..shuffle(Random());

  /// Cards turned up this turn (at most 2), by index.
  final _open = <int>[];

  /// Word ids whose pair was found.
  final _found = <String>{};
  bool _busy = false, _over = false;
  int _points = 0, _streak = 0, _bestStreak = 0, _misses = 0;

  Future<void> _flip(int i) async {
    final card = _cards[i];
    if (_busy || _over || _open.contains(i) || _found.contains(card.word.id)) {
      return;
    }
    setState(() => _open.add(i));
    // Children who can't read yet hear the word card.
    if (!card.picture) widget.speaker.say(card.word, _lang);
    if (_open.length < 2) return;

    final a = _cards[_open[0]], b = _cards[_open[1]];
    if (a.word.id == b.word.id && a.picture != b.picture) {
      _streak++;
      _bestStreak = max(_bestStreak, _streak);
      setState(() {
        _found.add(a.word.id);
        _points += pointsPerPair + streakBonus(_streak);
        _open.clear();
      });
      // Say the word for the match, unless the card just turned was the
      // word itself: it was read out a moment ago.
      if (card.picture) widget.speaker.say(a.word, _lang);
      await widget.session.record(
        activity: Activity.memoryMatch,
        word: a.word,
        chosen: a.word,
        latency: Duration.zero,
      );
      if (_found.length == _words.length) await _finish();
    } else {
      _streak = 0;
      _misses++;
      _busy = true;
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(_open.clear);
      _busy = false;
    }
  }

  Future<void> _finish() async {
    _over = true;
    await Future.delayed(const Duration(milliseconds: 700));
    _points += pointsRoundDone;
    final outcome = await widget.session.finishRound(
      activity: Activity.memoryMatch,
      category: widget.category,
      points: _points,
      correct: _words.length,
      questions: _words.length + _misses,
      bestStreak: _bestStreak,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoundDoneScreen(
          texts: widget.session.texts,
          stars: memoryStars(_misses, pairs: _words.length),
          outcome: outcome,
          bestStreak: _bestStreak,
          playAgain: () => MemoryMatchScreen(
            category: widget.category,
            session: widget.session,
            speaker: widget.speaker,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(widget.category);
    return Scaffold(
      appBar: AppBar(
        title: LinearProgressIndicator(
          value: _found.length / _words.length,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
        ),
        actions: [ScorePill(_points)],
      ),
      body: LayoutBuilder(
        builder: (_, box) {
          // 4 across on a wide screen (12 cards = 4 x 3), 3 across if narrow.
          final cols = box.maxWidth >= box.maxHeight ? 4 : 3;
          final rows = (_cards.length / cols).ceil();
          const gap = 16.0;
          final size = min(
            (box.maxWidth - gap * (cols + 1)) / cols,
            (box.maxHeight - gap * (rows + 1)) / rows,
          );
          return Center(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _cards.length; i++)
                  SizedBox(
                    width: max(size, 40) * (cols == 4 ? 1.2 : 1),
                    height: max(size, 40),
                    child: _MemoryCard(
                      key: ValueKey(_cards[i].id),
                      card: _cards[i],
                      lang: _lang,
                      color: color,
                      faceUp:
                          _open.contains(i) ||
                          _found.contains(_cards[i].word.id),
                      found: _found.contains(_cards[i].word.id),
                      onTap: () => _flip(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final _Card card;
  final String lang;
  final Color color;
  final bool faceUp;
  final bool found;
  final VoidCallback onTap;

  const _MemoryCard({
    super.key,
    required this.card,
    required this.lang,
    required this.color,
    required this.faceUp,
    required this.found,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => onTap(),
    // Flips around the vertical axis; the face shows past the halfway point.
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: faceUp ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      builder: (_, t, _) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(t * pi),
        child: t < 0.5
            ? _back()
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(pi),
                child: _front(),
              ),
      ),
    ),
  );

  Widget _back() => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
    ),
    child: const Center(
      child: Icon(Icons.question_mark_rounded, color: Colors.white, size: 56),
    ),
  );

  Widget _front() => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: found ? const Color(0xFF3CC46B) : color,
        width: found ? 6 : 4,
      ),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
    ),
    child: Center(
      child: card.picture
          ? LayoutBuilder(
              builder: (_, box) => WordPicture(
                card.word,
                size: min(box.maxWidth, box.maxHeight) * 0.85,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.word.label(lang),
                textAlign: TextAlign.center,
                style: wordStyle(size: 48, color: color),
              ),
            ),
    ),
  );
}

/// Stars for a Memory round, by wrong flips. Generous: finishing earns one.
int memoryStars(int misses, {int pairs = memoryPairs}) => misses <= pairs
    ? 3
    : misses <= pairs * 2
    ? 2
    : 1;
