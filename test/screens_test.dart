import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/config.dart';
import 'package:vocab_app/data/answer_log.dart';
import 'package:vocab_app/data/database.dart';
import 'package:vocab_app/data/learner_store.dart';
import 'package:vocab_app/data/round_log.dart';
import 'package:vocab_app/data/session.dart';
import 'package:vocab_app/data/speaker.dart';
import 'package:vocab_app/data/word_repository.dart';
import 'package:vocab_app/logic/scoring.dart';
import 'package:vocab_app/main.dart';
import 'package:vocab_app/vocab_game.dart';
import 'package:vocab_app/models/activity.dart';
import 'package:vocab_app/models/answer.dart';
import 'package:vocab_app/screens/kid_picker_screen.dart';
import 'package:vocab_app/models/learner.dart';
import 'package:vocab_app/models/word.dart';
import 'package:vocab_app/screens/home_screen.dart';
import 'package:vocab_app/screens/memory_match_screen.dart';
import 'package:vocab_app/theme.dart';
import 'package:vocab_app/widgets/why_note.dart';

void main() {
  sqfliteFfiInit();
  final words = WordRepository.fromJson(
    jsonDecode(File('content/words.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  late AnswerLog log;
  late LearnerStore learners;
  late Learner mia;
  late Session session;

  setUp(() async {
    // No-isolate factory so database futures complete inside widget tests.
    final db = await openAppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    log = AnswerLog(db);
    learners = LearnerStore(db);
    mia = await learners.add(name: 'Mia', avatar: 'cat');
    session = await Session.start(
      words: words,
      log: log,
      rounds: RoundLog(db),
      learnerId: mia.id,
      random: Random(7),
    );
  });
  tearDown(() => log.close());

  /// Mia's home screen, as if she had tapped her avatar.
  Future<void> openHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800)); // tablet
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: HomeScreen(
          session: session,
          speaker: Speaker.silent(),
          learner: mia,
        ),
      ),
    );
  }

  Future<void> openGame(WidgetTester tester, String game) async {
    await openHome(tester);
    await tester.tap(find.text('Animals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(game));
    await tester.pumpAndSettle();
  }

  /// The word the quiz is currently asking for.
  Word asked() => words
      .inCategory('animals')
      .firstWhere((w) => find.text(w.label('en')).evaluate().isNotEmpty);

  testWidgets('quiz: right tap is logged as correct', (tester) async {
    await openGame(tester, 'Find it');
    final target = asked();
    expect(find.byType(BigTile), findsNWidgets(4));

    await tester.tap(find.byKey(ValueKey(target.id)));
    await tester.pump(const Duration(seconds: 1));

    final s = session.stats[target.id]!;
    expect(s.graded, 1);
    expect(s.missed, 0);
    expect(await log.all(learnerId: mia.id), hasLength(1));
  });

  testWidgets('quiz: wrong tap logs which option was chosen', (tester) async {
    await openGame(tester, 'Find it');
    final target = asked();
    final wrong = tester
        .widgetList<BigTile>(find.byType(BigTile))
        .map((b) => (b.key as ValueKey<String>).value)
        .firstWhere((id) => id != target.id);

    await tester.tap(find.byKey(ValueKey(wrong)));
    await tester.tap(find.byKey(ValueKey(target.id))); // second tap ignored
    await tester.pump(const Duration(seconds: 3));

    final rows = await log.all(learnerId: mia.id);
    expect(rows, hasLength(1));
    expect(rows.single.chosen, wrong);
    expect(rows.single.correct, isFalse);
  });

  testWidgets('quiz: a full round ends on the stars screen', (tester) async {
    await openGame(tester, 'Find it');
    for (var i = 0; i < roundLength; i++) {
      await tester.tap(find.byKey(ValueKey(asked().id)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(await log.all(learnerId: mia.id), hasLength(roundLength));
  });

  testWidgets('quiz: no word twice in a round, even when all wrong', (
    tester,
  ) async {
    await openGame(tester, 'Find it');
    final seen = <String>[];
    for (var i = 0; i < roundLength; i++) {
      final target = asked();
      seen.add(target.id);
      final wrong = tester
          .widgetList<BigTile>(find.byType(BigTile))
          .map((b) => (b.key as ValueKey<String>).value)
          .firstWhere((id) => id != target.id);
      await tester.tap(find.byKey(ValueKey(wrong)));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }
    expect(seen.toSet(), hasLength(roundLength), reason: '$seen');
  });

  testWidgets('flashcards: each card is logged as ungraded', (tester) async {
    await openGame(tester, 'Cards');
    final shown = <String>{};
    for (var i = 0; i < roundLength; i++) {
      shown.add(
        words
            .inCategory('animals')
            .firstWhere((w) => find.text(w.label('en')).evaluate().isNotEmpty)
            .id,
      );
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    final rows = await log.all(learnerId: mia.id);
    expect(rows, hasLength(roundLength));
    expect(rows.every((a) => a.activityType == 'flashcard'), isTrue);
    expect(session.stats.values.every((s) => s.graded == 0), isTrue);
    expect(find.byKey(const Key('fact')), findsNothing, reason: 'round over');
    expect(shown, hasLength(roundLength), reason: 'no card repeats in a round');
  });

  testWidgets('demo notes are hidden unless a teacher turns them on', (
    tester,
  ) async {
    await openGame(tester, 'Find it');
    expect(find.byType(WhyNote), findsNothing);
    expect(find.text('New word'), findsNothing);

    // Back out, switch demo mode on, start a fresh round.
    session.showWhy = true;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find it'));
    await tester.pumpAndSettle();
    expect(find.text('New word'), findsOneWidget);
    expect(find.textContaining('Easy choices'), findsOneWidget);
  });

  testWidgets('quiz: right answers earn points shown in the corner', (
    tester,
  ) async {
    await openGame(tester, 'Find it');
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(asked().id)));
    await tester.pump(const Duration(milliseconds: 400));
    // +10 for right, +5 for under 3 seconds.
    expect(find.text('+15'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('quiz: a perfect round shows points, best and level up', (
    tester,
  ) async {
    await openGame(tester, 'Find it');
    for (var i = 0; i < roundLength; i++) {
      await tester.tap(find.byKey(ValueKey(asked().id)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    expect(find.textContaining('Level up!'), findsOneWidget);
    expect(session.totalPoints, greaterThan(100));
    expect(
      find.text('+${session.totalPoints} points'),
      findsOneWidget,
      reason: 'only round so far, so round points = total',
    );

    // Home shows the new level after returning.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Level ${session.level}'), findsOneWidget);
    expect(
      find.text('Best Find it: ${session.bestPoints(Activity.pictureQuiz)}'),
      findsOneWidget,
    );
  });

  testWidgets('Mix everything asks words from more than one group', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.text('Mix everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find it'));
    await tester.pumpAndSettle();
    final groups = <String>{};
    for (var i = 0; i < roundLength; i++) {
      final target = words.words.firstWhere(
        (w) => find.text(w.label('en')).evaluate().isNotEmpty,
      );
      groups.add(target.category);
      await tester.tap(find.byKey(ValueKey(target.id)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(groups.length, greaterThan(1), reason: '$groups');
  });

  testWidgets('cards show the word\'s fact', (tester) async {
    await openGame(tester, 'Cards');
    final shown = words
        .inCategory('animals')
        .firstWhere((w) => find.text(w.label('en')).evaluate().isNotEmpty);
    expect(find.text(shown.factIn('en')!), findsOneWidget);
  });

  group('Flip & Match', () {
    /// Word ids on the board, from the picture cards' keys.
    List<String> board() => [
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('pic-'),
              )
              .evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(4),
    ];

    Future<void> flip(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }

    testWidgets('6 pairs: a picture and its word stay open', (tester) async {
      await openGame(tester, 'Flip & Match');
      final ids = board();
      expect(ids, hasLength(6));
      expect(ids.toSet(), hasLength(6));

      await flip(tester, 'pic-${ids[0]}');
      await flip(tester, 'word-${ids[0]}');
      await tester.pumpAndSettle();
      final rows = await log.all(learnerId: mia.id);
      expect(rows.single.activityType, 'memory_match');
      expect(session.stats[ids[0]]!.graded, 0, reason: 'practice, not a test');
    });

    testWidgets('a match says the word once, not twice', (tester) async {
      final speaker = _CountingSpeaker();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: MemoryMatchScreen(
            category: 'animals',
            session: session,
            speaker: speaker,
          ),
        ),
      );
      final ids = board();
      await flip(tester, 'pic-${ids[0]}');
      await flip(tester, 'word-${ids[0]}');
      await tester.pumpAndSettle();
      expect(speaker.said, [ids[0]], reason: 'word card read once');

      await flip(tester, 'word-${ids[1]}');
      await flip(tester, 'pic-${ids[1]}');
      await tester.pumpAndSettle();
      expect(speaker.said, [
        ids[0],
        ids[1],
        ids[1],
      ], reason: 'word read on flip, then again for the match');
    });

    testWidgets('a wrong pair turns back over and is not logged', (
      tester,
    ) async {
      await openGame(tester, 'Flip & Match');
      final ids = board();
      await flip(tester, 'pic-${ids[0]}');
      await flip(tester, 'word-${ids[1]}');
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(await log.all(learnerId: mia.id), isEmpty);

      // Both cards can be flipped again: they were turned back.
      await flip(tester, 'pic-${ids[0]}');
      await flip(tester, 'word-${ids[0]}');
      await tester.pumpAndSettle();
      expect(await log.all(learnerId: mia.id), hasLength(1));
    });

    testWidgets('finding every pair ends the round; practice, no best', (
      tester,
    ) async {
      await openGame(tester, 'Flip & Match');
      for (final id in board()) {
        await flip(tester, 'pic-$id');
        await flip(tester, 'word-$id');
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Great job!'), findsOneWidget);
      expect(find.text('+20 points'), findsOneWidget, reason: 'finishing');
      expect(find.text('New best!'), findsNothing);
      expect(session.bestPoints(Activity.memoryMatch), 0);
      expect(session.totalPoints, pointsRoundDone);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Best Flip & Match'), findsNothing);
    });
  });

  group('Bubble Pop', () {
    // Not openGame: settling would fast-forward through the animated round.
    Future<void> openBubblePop(WidgetTester tester) async {
      await openHome(tester);
      await tester.tap(find.text('Animals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bubble Pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // page transition
    }

    testWidgets('popping the right bubble scores and is logged', (
      tester,
    ) async {
      await openBubblePop(tester);
      // Let the bubbles float up into view (past the 3 s fast bonus).
      await tester.pump(const Duration(milliseconds: 3500));
      final target = asked();
      await tester.tap(find.byKey(ValueKey(target.id)));
      await tester.pump(const Duration(milliseconds: 100));

      final rows = await log.all(learnerId: mia.id);
      expect(rows.single.activityType, Activity.bubblePop.key);
      expect(rows.single.correct, isTrue);
      expect(find.byKey(const Key('score')), findsOneWidget);
      final score = tester.widget<Text>(find.byKey(const Key('score'))).data;
      expect(score, '10', reason: '+10, slower than 3 s');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a bubble that floats away is a miss, not a mix-up', (
      tester,
    ) async {
      await openBubblePop(tester);
      final target = asked();
      await tester.pump(bubbleRiseStart);
      expect(find.byKey(const Key('it-was')), findsOneWidget);

      final rows = await log.all(learnerId: mia.id);
      expect(rows.single.wordId, target.id);
      expect(rows.single.chosen, timedOut);
      expect(rows.single.correct, isFalse);
      expect(session.stats[target.id]!.missed, 1);
      expect(session.stats[target.id]!.confusions, isEmpty);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the round ends after 60 seconds with no repeats', (
      tester,
    ) async {
      await openBubblePop(tester);
      final seen = <String>[];
      var last = '';
      for (var i = 0; i < 70; i++) {
        if (find.text('Great job!').evaluate().isNotEmpty) break;
        final now = asked().id;
        if (now != last) seen.add(now);
        last = now;
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Great job!'), findsOneWidget);
      expect(seen.toSet(), hasLength(seen.length), reason: '$seen');
      final rows = await log.all(learnerId: mia.id);
      expect(rows.every((a) => !a.correct), isTrue, reason: 'never tapped');
      expect(session.bestPoints(Activity.bubblePop), pointsRoundDone);
    });
  });

  testWidgets('switching to Español changes the screens and the words', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.byKey(const ValueKey('lang-es')));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Mia! ¿Qué vas a aprender hoy?'), findsOneWidget);
    expect(find.text('Todo mezclado'), findsOneWidget);
    expect(find.text('Nivel 1'), findsOneWidget);

    await tester.tap(find.text('Animales'));
    await tester.pumpAndSettle();
    expect(find.text('Tarjetas'), findsOneWidget);
    await tester.tap(find.text('Encuéntralo'));
    await tester.pumpAndSettle();
    final shown = words
        .inCategory('animals')
        .where((w) => find.text(w.label('es')).evaluate().isNotEmpty);
    expect(shown, hasLength(1), reason: 'the word is asked in Spanish');
    expect(shown.single.label('es'), matches(RegExp('^(el|la) ')));

    // The answer is logged as Spanish.
    await tester.tap(find.byKey(ValueKey(shown.single.id)));
    await tester.pumpAndSettle();
    final logged = await log.all(learnerId: mia.id);
    expect(logged.last.language, 'es');
  });

  group('VocabGame (for plugging into a bigger app)', () {
    Future<void> openGame(
      WidgetTester tester, {
      String player = defaultPlayer,
      String? name,
      VoidCallback? onExit,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      // The test bundle caches files from an earlier test, and that cached
      // load never finishes here. Not an issue in the real app.
      rootBundle.clear();
      await tester.pumpWidget(
        VocabGame(
          playerId: player,
          playerName: name,
          onExit: onExit,
          speaker: Speaker.silent(),
          databaseFactory: databaseFactoryFfiNoIsolate,
          databasePath: inMemoryDatabasePath,
        ),
      );
      // Setup (database, words) is real async work: let it run until the
      // home screen shows (up to 10 s).
      for (var i = 0; i < 200; i++) {
        if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.byType(HomeScreen), findsOneWidget);
    }

    testWidgets('sets itself up and opens straight to the groups', (
      tester,
    ) async {
      await openGame(tester);
      expect(find.text('What will you learn today?'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text("Who's playing?"), findsNothing);
      expect(find.byTooltip('Exit'), findsNothing);
    });

    testWidgets('greets the player and can exit back to the host', (
      tester,
    ) async {
      var exited = false;
      await openGame(
        tester,
        player: '123',
        name: 'Mia',
        onExit: () => exited = true,
      );
      expect(find.textContaining('Hi Mia!'), findsOneWidget);
      await tester.tap(find.byTooltip('Exit'));
      expect(exited, isTrue);
    });
  });

  test('a name in the link picks the player', () {
    String from(String url) => playerFromLink(Uri.parse(url));
    expect(from('http://localhost:8081/'), defaultPlayer);
    expect(from('http://localhost:8081/?kid=Mia'), 'mia');
    expect(from('http://localhost:8081/?kid=sam_2'), 'sam_2');
    expect(from('http://localhost:8081/?kid='), defaultPlayer);
    expect(from('http://localhost:8081/?kid=<b>x</b>'), defaultPlayer);
  });

  testWidgets('teacher screen needs the passcode', (tester) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('Teacher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Words to work on'), findsNothing);

    await tester.tap(find.byTooltip('Teacher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), teacherPasscode);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Words to work on'), findsOneWidget);
  });

  group('kid picker', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: KidPickerScreen(
            words: words,
            log: log,
            learners: learners,
            speaker: Speaker.silent(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a kid opens their home screen', (tester) async {
      await openPicker(tester);
      expect(find.text("Who's playing?"), findsOneWidget);
      await tester.tap(find.text('Mia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hi Mia!'), findsOneWidget);
    });

    testWidgets('adding a kid needs the teacher code', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text('Add a kid'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsNothing, reason: 'wrong code');

      await tester.tap(find.text('Add a kid'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), teacherPasscode);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Leo');
      await tester.tap(find.byKey(const ValueKey('avatar-dog')));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Leo'), findsOneWidget);
      final kids = await learners.all();
      expect(kids.map((k) => k.name), ['Mia', 'Leo']);
      expect(kids.last.avatar, 'dog');
    });
  });
}

/// Records which words were spoken.
class _CountingSpeaker extends Speaker {
  final said = <String>[];

  _CountingSpeaker() : super.silent();

  @override
  Future<void> say(Word word, String lang) async => said.add(word.id);
}
