import 'package:flutter/material.dart';

import '../config.dart';
import '../data/session.dart';
import '../data/speaker.dart';
import '../l10n.dart';
import '../models/activity.dart';
import '../models/learner.dart';
import '../theme.dart';
import '../widgets/score.dart';
import '../widgets/word_picture.dart';
import 'game_picker_screen.dart';
import 'kid_picker_screen.dart';
import 'teacher_screen.dart';

/// Children pick a category here: one bright tile per group, plus "Mix
/// everything". Their level and points sit on top.
class HomeScreen extends StatefulWidget {
  final Session session;
  final Speaker speaker;

  /// The child playing, if picked on the (currently unused) kid picker.
  final Learner? learner;

  /// Name to greet, when the player came from a host app or the link.
  final String? playerName;

  /// Leaves the game (back to a host app). No exit button when null.
  final VoidCallback? onExit;

  const HomeScreen({
    super.key,
    required this.session,
    required this.speaker,
    this.learner,
    this.playerName,
    this.onExit,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Session get session => widget.session;
  Learner? get learner => widget.learner;

  void _openGroup(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePickerScreen(
          category: category,
          session: session,
          speaker: widget.speaker,
        ),
      ),
    );
  }

  /// Redraws everything when the language or the points change.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: session, builder: (context, _) => _page());

  Widget _page() {
    final words = session.words;
    final t = session.texts;
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'build $buildLabel',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      appBar: AppBar(
        leading: widget.onExit == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: t.exit,
                onPressed: widget.onExit,
              ),
        title: learner == null
            ? Text(
                widget.playerName == null
                    ? t.learnToday
                    : t.hi(widget.playerName!),
                overflow: TextOverflow.ellipsis,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(words, learner!.avatar, size: 48),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      t.hi(learner!.name),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          _LanguageSwitch(session),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Teacher',
            onPressed: () => openTeacher(context, session),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Wrap(
                spacing: 32,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LevelBar(session.totalPoints, texts: t, width: 380),
                  for (final game in Activity.values.where((a) => a.hasBest))
                    if (session.bestPoints(game) > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFFFB020),
                            size: 36,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.best(t.game(game), session.bestPoints(game)),
                            style: wordStyle(size: 22),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid.extent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 1.15,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              children: [
                BigTile(
                  key: const ValueKey('mix'),
                  color: categoryColor(mixCategory),
                  onTap: () => _openGroup(mixCategory),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shuffle_rounded,
                          size: 64,
                          color: categoryColor(mixCategory),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        session.groupName(mixCategory),
                        style: wordStyle(size: 30, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                for (final category in words.categories)
                  BigTile(
                    color: categoryColor(category),
                    onTap: () => _openGroup(category),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: WordPicture(
                            words.inCategory(category).first,
                            size: 72,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          session.groupName(category),
                          style: wordStyle(size: 30, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "English | Español", like the switch in the main app's games.
class _LanguageSwitch extends StatelessWidget {
  final Session session;

  const _LanguageSwitch(this.session);

  @override
  Widget build(BuildContext context) => ToggleButtons(
    isSelected: [for (final l in languages) l == session.language],
    onPressed: (i) => session.setLanguage(languages[i]),
    borderRadius: BorderRadius.circular(24),
    borderWidth: 2,
    fillColor: categoryColor(mixCategory),
    constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
    children: [
      for (final l in languages)
        Padding(
          key: ValueKey('lang-$l'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            textsFor(l).name,
            style: wordStyle(
              size: 18,
              color: l == session.language ? Colors.white : ink,
            ),
          ),
        ),
    ],
  );
}
