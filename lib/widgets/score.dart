import 'package:flutter/material.dart';

import '../l10n.dart';
import '../logic/scoring.dart';
import '../theme.dart';

const gold = Color(0xFFFFC53D);

/// A rounded "★ 120" badge for the corner of game screens.
class ScorePill extends StatelessWidget {
  final int points;

  const ScorePill(this.points, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: gold, size: 30),
        const SizedBox(width: 4),
        Text('$points', key: const Key('score'), style: wordStyle(size: 26)),
      ],
    ),
  );
}

/// "Level 3" badge with a bar showing progress to the next level.
class LevelBar extends StatelessWidget {
  final int totalPoints;
  final double width;
  final Texts texts;

  const LevelBar(
    this.totalPoints, {
    super.key,
    required this.texts,
    this.width = 320,
  });

  @override
  Widget build(BuildContext context) {
    final level = levelFor(totalPoints);
    final toNext = levelStart(level + 1) - totalPoints;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: gold,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x55FF8A3D), blurRadius: 12)],
            ),
            child: Text(
              '$level',
              style: wordStyle(size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(texts.level(level), style: wordStyle(size: 22)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: levelProgress(totalPoints),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  color: gold,
                  backgroundColor: gold.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 2),
                Text(
                  texts.levelLine(totalPoints, toNext, level + 1),
                  style: const TextStyle(fontSize: 14, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
