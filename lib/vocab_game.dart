import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/answer_log.dart';
import 'data/database.dart';
import 'data/round_log.dart';
import 'data/session.dart';
import 'data/speaker.dart';
import 'data/word_repository.dart';
import 'models/new_best.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

export 'models/new_best.dart';

/// The whole vocabulary game as one widget, so another app can open it like
/// any screen. It sets itself up (database, words, voice); the caller only
/// says who is playing.
///
/// ```dart
/// VocabGame(
///   playerId: pin,                       // from the host's login
///   onNewBest: (best) => saveScore(best), // optional
///   onExit: () => Navigator.pop(context), // optional
///   language: 'es',                       // optional
/// )
/// ```
///
/// Everything (scores, bests, which words a child knows) is kept per
/// [playerId] on the device.
class VocabGame extends StatelessWidget {
  final String playerId;

  /// Shown as a greeting ("Hi Mia!"). No greeting when null.
  final String? playerName;

  /// Called when the player beats their own best in a game.
  final void Function(NewBest best)? onNewBest;

  /// Shows a back button on the home screen that calls this.
  final VoidCallback? onExit;

  /// Start in this language ("en" or "es"), e.g. the host app's current
  /// language. When null: English. Children can switch on the home screen.
  final String? language;

  /// For tests: a silent speaker and an in-memory database.
  final Speaker? speaker;
  final DatabaseFactory? databaseFactory;
  final String? databasePath;

  const VocabGame({
    super.key,
    required this.playerId,
    this.playerName,
    this.onNewBest,
    this.onExit,
    this.language,
    this.speaker,
    this.databaseFactory,
    this.databasePath,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    // A different player starts fresh, never on the last player's screens.
    key: ValueKey(playerId),
    title: 'Vocab App',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: _Loader(game: this),
  );
}

class _Loader extends StatefulWidget {
  final VocabGame game;

  const _Loader({required this.game});

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late final Speaker _speaker = widget.game.speaker ?? Speaker();
  late final Future<Session> _session = _open();

  Future<Session> _open() async {
    final g = widget.game;
    final db = await openAppDatabase(
      factory: g.databaseFactory,
      path: g.databasePath,
    );
    return Session.start(
      words: await WordRepository.load(),
      log: AnswerLog(db),
      rounds: RoundLog(db),
      learnerId: g.playerId,
      onNewBest: g.onNewBest,
      language: g.language,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Session>(
    future: _session,
    builder: (context, snap) {
      if (snap.hasError) {
        debugPrint('VocabGame failed to start: ${snap.error}');
        return const Scaffold(
          body: Center(child: Text('Sorry, the game could not start.')),
        );
      }
      if (!snap.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return HomeScreen(
        session: snap.data!,
        speaker: _speaker,
        playerName: widget.game.playerName,
        onExit: widget.game.onExit,
      );
    },
  );
}
