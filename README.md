# Vocab App

An offline, picture-based vocabulary game for elementary students on a shared
classroom tablet. It tracks which words each child is forgetting and brings
them back at the right time.

CSEN 293 Directed Research, Santa Clara University.

## Layout

- `content/` — the word list (`words.json`) and notes on how it was built.
- `lib/vocab_game.dart` — the whole game as one widget (see below);
  `lib/main.dart` runs it on its own.
- `lib/models/` — `Word`, `Answer`, `Activity`, `NewBest`.
- `lib/logic/` — pure functions, no storage: `stats.dart` (rolls the answer
  log into per-word Leitner boxes) and `selector.dart` (picks the next word
  and its wrong options).
- `lib/data/` — `WordRepository` (loads the word list), `AnswerLog`
  (append-only SQLite log of every answer), `Session` (connects the selector
  to the log), `Speaker` (text-to-speech).
- `lib/screens/` — Home (pick a group or Mix everything) → game picker →
  Cards, Find it, Bubble Pop or Flip & Match → round done (points, best, level). Teacher screen behind a passcode. Styling is a
  placeholder; the final UI is still to be designed.
- `lib/widgets/` — `WordPicture` (shows the word's bundled image).
- `lib/l10n.dart` — languages (English, Spanish) and all text children
  read on screen. Words and facts per language are in `content/words.json`.
- `lib/config.dart` — teacher passcode, round length, game timing.
- `lib/theme.dart` — kid-friendly look: Fredoka font (OFL, bundled in
  `assets/fonts/`), one bright colour per category, `BigTile`.

## Run

For now the app targets desktop, running in Chrome:

```
flutter pub get
flutter test
flutter run -d chrome
```

To use the built version in any browser (no debug tools), build and serve it
with caching off, then open http://localhost:8081:

```
sh tool/build_web.sh
python3 tool/serve_web.py
```

`build_web.sh` stamps the build time (shown bottom right of the home screen)
and gives the app code a new URL each build, so a reload always gets the new
code. Don't use plain `python3 -m http.server`: it sends no cache headers and
Chrome kept an old `main.dart.js` across reloads.

In the browser, SQLite runs as WebAssembly (`web/sqlite3.wasm`,
`web/sqflite_sw.js`) and answers are saved in the browser's storage.

## Players

Everything (points, bests, which words a child knows) is kept per player id.
To try two children on one machine, put a name in the link:
http://localhost:8081/?kid=mia and http://localhost:8081/?kid=sam. This is
only for testing, not a login. With no name, everyone shares one player.

## Games

- **Cards** — learn: picture, word, voice and a fun fact. Practice only.
- **Find it** — hear a word, tap its picture out of four. Graded.
- **Bubble Pop** — 60 s; pop the picture bubble before it floats away. Graded.
- **Flip & Match** (Spanish: Memorama) — 6 pairs face down (a picture and its word); flip two at a
  time. Words are chosen adaptively, but found pairs count as practice, not
  right/wrong: a wrong flip is usually a memory slip, not a vocabulary
  mistake.

Every game but Cards keeps a personal best per child.

## Languages

English and Spanish (Latin American, words with their article: "el gato").
The app always opens in English; children switch with **English | Español**
on the home screen. Words, facts, voice and screen text all change.
Teacher screens stay in English.

Word progress is kept **per language** (knowing "cat" is not knowing
"el gato"), so the adaptive order starts fresh in Spanish. Points and best
scores are one total per child.

`content/spanish_review.csv` lists every Spanish word and fact, with notes
on regional choices (e.g. papalote / cometa for kite), for a native speaker
to check. After corrections, edit `tool/add_spanish.py` and run
`python3 tool/add_spanish.py` to update `words.json`.

## Plugging into a bigger app

The whole game is one widget, `VocabGame` (`lib/vocab_game.dart`). It sets
itself up (database, words, voice); the host only says who is playing:

```dart
VocabGame(
  playerId: pin,                          // the host's logged-in child
  playerName: name,                       // optional: "Hi Mia!"
  onNewBest: (best) => saveScore(best),   // optional
  onExit: () => Navigator.pop(context),   // optional: shows a back button
  language: 'es',                         // optional: start in Spanish
)
```

`onNewBest` fires when a child beats their own best in a game, with
`playerId`, `game` (e.g. `bubble_pop`), `gameName` and `score`. The app does
not save scores anywhere else itself; the host decides where they go.

Still to agree with the host app: one combined score or one per game, and
whether word progress should be stored online. On the web, the host also
needs `web/sqlite3.wasm` and `web/sqflite_sw.js` from this app.
