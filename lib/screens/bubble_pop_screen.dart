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

/// Arcade game: the app says a word and four picture bubbles float up. Pop
/// the right one before it floats away. 60 seconds, as many as you can; each
/// word at most once per round. Words and choices come from the same adaptive
/// engine as Find it, and every answer (including a bubble that got away) is
/// logged.
class BubblePopScreen extends StatefulWidget {
  final String category;
  final Session session;
  final Speaker speaker;

  const BubblePopScreen({
    super.key,
    required this.category,
    required this.session,
    required this.speaker,
  });

  @override
  State<BubblePopScreen> createState() => _BubblePopScreenState();
}

class _BubblePopScreenState extends State<BubblePopScreen>
    with TickerProviderStateMixin {
  String get _lang => widget.session.language;

  /// Counts down the whole round.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: bubbleRoundTime)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _finish();
        });

  /// Moves the current bubbles from the bottom (0) to off the top (1).
  late final AnimationController _rise = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _answer(null);
    });

  final _rng = Random();
  final _asked = <String>{};
  late final int _poolSize = widget.session.words.pool(widget.category).length;

  late Word _word;
  late List<Word> _options;

  /// How far below the screen each bubble starts (0–1), so they don't rise
  /// in a straight line.
  late List<double> _lag;
  Duration _riseTime = bubbleRiseStart;

  bool _hard = false;

  /// Set once this question is answered (or missed) until the next one.
  bool _locked = false;
  String? _popped;
  String? _wrong;

  /// Shows the right picture ("it was this one") after a miss.
  bool _reveal = false;
  bool _over = false;

  int _points = 0, _streak = 0, _bestStreak = 0, _correct = 0, _questions = 0;
  AnswerPoints? _gain;

  @override
  void initState() {
    super.initState();
    _clock.forward();
    _next();
  }

  @override
  void dispose() {
    _clock.dispose();
    _rise.dispose();
    super.dispose();
  }

  void _next() {
    if (_over || !mounted) return;
    if (_asked.length >= _poolSize) {
      _finish(); // every word in the group asked once
      return;
    }
    final session = widget.session;
    final pick = session.nextPick(widget.category, askedThisRound: _asked);
    setState(() {
      _word = pick.word;
      _asked.add(_word.id);
      _hard = session.isHard(_word);
      _options = session.optionsFor(_word);
      _lag = [for (var i = 0; i < 4; i++) _rng.nextDouble()];
      _locked = false;
      _popped = null;
      _wrong = null;
      _reveal = false;
      _gain = null;
    });
    _rise
      ..duration = _riseTime
      ..forward(from: 0);
    widget.speaker.say(_word, _lang);
  }

  /// [chosen] is null when the right bubble floated away.
  Future<void> _answer(Word? chosen) async {
    if (_locked || _over) return;
    _locked = true;
    // Time since the bubbles appeared, from the rise animation itself.
    final latency = _riseTime * _rise.value;
    _rise.stop();
    final right = chosen?.id == _word.id;
    _questions++;
    _streak = right ? _streak + 1 : 0;
    if (_streak > _bestStreak) _bestStreak = _streak;
    final gain = scoreAnswer(
      correct: right,
      streak: _streak,
      latency: latency,
      hard: _hard,
    );
    setState(() {
      _points += gain.total;
      if (right) {
        _correct++;
        _popped = chosen!.id;
        _gain = gain;
        final faster = _riseTime - bubbleRiseStep;
        _riseTime = faster < bubbleRiseMin ? bubbleRiseMin : faster;
      } else {
        _wrong = chosen?.id;
        _reveal = true;
      }
    });
    await widget.session.record(
      activity: Activity.bubblePop,
      word: _word,
      chosen: chosen,
      latency: latency,
    );
    await Future.delayed(Duration(milliseconds: right ? 600 : 1600));
    _next();
  }

  Future<void> _finish() async {
    if (_over || !mounted) return;
    _over = true;
    _rise.stop();
    _clock.stop();
    _points += pointsRoundDone;
    final outcome = await widget.session.finishRound(
      activity: Activity.bubblePop,
      category: widget.category,
      points: _points,
      correct: _correct,
      questions: _questions,
      bestStreak: _bestStreak,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoundDoneScreen(
          texts: widget.session.texts,
          stars: bubbleStars(_correct),
          outcome: outcome,
          bestStreak: _bestStreak,
          playAgain: () => BubblePopScreen(
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
        title: AnimatedBuilder(
          animation: _clock,
          builder: (_, _) => Row(
            children: [
              Icon(Icons.timer_rounded, color: color, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: 1 - _clock.value,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
        actions: [ScorePill(_points)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _word.label(_lang),
                  style: wordStyle(size: 60, color: color),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, size: 44, color: color),
                  tooltip: widget.session.texts.sayIt,
                  onPressed: () => widget.speaker.say(_word, _lang),
                ),
                if (_gain != null) ...[
                  const SizedBox(width: 12),
                  _Gain(_gain!, streak: _streak),
                ],
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => ClipRect(
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _rise,
                      builder: (_, _) => Stack(children: _bubbles(box, color)),
                    ),
                    if (_reveal)
                      Center(
                        child: _ItWas(_word, lang: _lang, color: color),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bubbles(BoxConstraints box, Color color) {
    final w = box.maxWidth, h = box.maxHeight;
    final lane = w / 4;
    final size = min(lane * 0.8, min(180.0, h * 0.4));
    final maxLag = h * 0.35;
    final t = _rise.value;
    return [
      for (var i = 0; i < _options.length; i++)
        Positioned(
          // Each bubble wobbles a little sideways as it rises.
          left:
              lane * (i + 0.5) -
              size / 2 +
              sin(t * 2 * pi * 1.5 + i) * lane * 0.08,
          top: h + _lag[i] * maxLag - t * (h + size + maxLag),
          child: _Bubble(
            key: ValueKey(_options[i].id),
            word: _options[i],
            size: size,
            color: color,
            popped: _popped == _options[i].id,
            wrong: _wrong == _options[i].id,
            onTap: () => _answer(_options[i]),
          ),
        ),
    ];
  }
}

class _Bubble extends StatelessWidget {
  final Word word;
  final double size;
  final Color color;
  final bool popped;
  final bool wrong;
  final VoidCallback onTap;

  const _Bubble({
    super.key,
    required this.word,
    required this.size,
    required this.color,
    required this.popped,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: popped ? 1.5 : 1,
    duration: const Duration(milliseconds: 250),
    child: AnimatedOpacity(
      opacity: popped ? 0 : (wrong ? 0.35 : 1),
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                Colors.white,
                Color.lerp(Colors.white, color, 0.25)!,
                color.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16),
            ],
          ),
          child: WordPicture(word, size: size * 0.6),
        ),
      ),
    ),
  );
}

/// After a miss: shows the right picture so the child sees it.
class _ItWas extends StatelessWidget {
  final Word word;
  final String lang;
  final Color color;

  const _ItWas(this.word, {required this.lang, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('it-was'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: const Color(0xFF3CC46B), width: 6),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WordPicture(word, size: 150),
        Text(word.label(lang), style: wordStyle(size: 40, color: color)),
      ],
    ),
  );
}

/// "+20 🔥 3 in a row!" after a pop.
class _Gain extends StatelessWidget {
  final AnswerPoints gain;
  final int streak;

  const _Gain(this.gain, {required this.streak});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF3CC46B),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('+${gain.total}', style: wordStyle(size: 28, color: Colors.white)),
        if (streak >= 2) ...[
          const SizedBox(width: 8),
          const Icon(Icons.local_fire_department_rounded, color: gold),
          Text('$streak', style: wordStyle(size: 22, color: Colors.white)),
        ],
      ],
    ),
  );
}

/// Stars for a Bubble Pop round, by words popped.
int bubbleStars(int popped) => popped >= 8
    ? 3
    : popped >= 4
    ? 2
    : 1;
