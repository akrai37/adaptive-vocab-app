import 'package:flutter/material.dart';

import '../data/session.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/score.dart';

/// End of a round: stars, points earned, any new best or level-up, then
/// play again or go home.
class RoundDoneScreen extends StatelessWidget {
  final int stars;
  final RoundOutcome outcome;

  /// Longest run of right answers this round (0 for Cards).
  final int bestStreak;
  final Widget Function() playAgain;
  final Texts texts;

  const RoundDoneScreen({
    super.key,
    required this.stars,
    required this.outcome,
    required this.playAgain,
    required this.texts,
    this.bestStreak = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 120,
                      color: gold,
                      shadows: const [
                        Shadow(color: Color(0x55FF8A3D), blurRadius: 24),
                      ],
                    ),
                ],
              ),
              Text(
                texts.greatJob,
                style: wordStyle(size: 60, color: const Color(0xFFFF5C7A)),
              ),
              const SizedBox(height: 8),
              Text(
                texts.plusPoints(outcome.points),
                key: const Key('round-points'),
                style: wordStyle(size: 40, color: const Color(0xFF3CC46B)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (outcome.newBest)
                    _Badge(
                      icon: Icons.emoji_events_rounded,
                      text: texts.newBest,
                      color: const Color(0xFFFFB020),
                    ),
                  if (outcome.levelUp)
                    _Badge(
                      icon: Icons.rocket_launch_rounded,
                      text: texts.levelUp(outcome.levelAfter),
                      color: const Color(0xFFA06CF2),
                    ),
                  if (bestStreak >= 3)
                    _Badge(
                      icon: Icons.local_fire_department_rounded,
                      text: texts.inARow(bestStreak),
                      color: const Color(0xFFFF8A3D),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              LevelBar(outcome.totalPoints, texts: texts, width: 380),
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BigButton(
                    icon: Icons.replay,
                    text: texts.again,
                    color: const Color(0xFF3CC46B),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => playAgain()),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _BigButton(
                    icon: Icons.home,
                    text: texts.home,
                    color: const Color(0xFF3FA7F5),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Badge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(width: 8),
        Text(text, style: wordStyle(size: 24, color: Colors.white)),
      ],
    ),
  );
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const _BigButton({
    required this.icon,
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
    ),
    icon: Icon(icon, size: 40),
    label: Text(text, style: wordStyle(size: 30, color: Colors.white)),
    onPressed: onPressed,
  );
}
