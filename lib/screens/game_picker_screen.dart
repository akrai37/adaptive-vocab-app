import 'package:flutter/material.dart';

import '../data/session.dart';
import '../data/speaker.dart';
import '../models/activity.dart';
import '../theme.dart';
import 'bubble_pop_screen.dart';
import 'flashcard_screen.dart';
import 'memory_match_screen.dart';
import 'quiz_screen.dart';

/// The child picks which game to play; the app picks the words.
class GamePickerScreen extends StatelessWidget {
  final String category;
  final Session session;
  final Speaker speaker;

  const GamePickerScreen({
    super.key,
    required this.category,
    required this.session,
    required this.speaker,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);

    Widget game(IconData icon, String label, Widget Function() screen) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BigTile(
              color: color,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => screen()),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 140, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(label, style: wordStyle(size: 40, color: Colors.white)),
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.groupName(category),
          style: wordStyle(size: 36, color: color),
        ),
      ),
      body: Row(
        children: [
          game(
            Icons.style,
            session.texts.game(Activity.flashcard),
            () => FlashcardScreen(
              category: category,
              session: session,
              speaker: speaker,
            ),
          ),
          game(
            Icons.search,
            session.texts.game(Activity.pictureQuiz),
            () => QuizScreen(
              category: category,
              session: session,
              speaker: speaker,
            ),
          ),
          game(
            Icons.bubble_chart_rounded,
            session.texts.game(Activity.bubblePop),
            () => BubblePopScreen(
              category: category,
              session: session,
              speaker: speaker,
            ),
          ),
          game(
            Icons.grid_view_rounded,
            session.texts.game(Activity.memoryMatch),
            () => MemoryMatchScreen(
              category: category,
              session: session,
              speaker: speaker,
            ),
          ),
        ],
      ),
    );
  }
}
