# Embedding the game in another app

The whole game is a single Flutter widget, `VocabGame`
(`lib/vocab_game.dart`). It sets itself up (database, word list, voice), so a
host app only needs to say who is playing.

```dart
import 'package:vocab_app/vocab_game.dart';

VocabGame(
  playerId: pin,                          // the host's logged-in child
  playerName: name,                       // optional: greets "Hi Mia!"
  onNewBest: (best) => saveScore(best),   // optional
  onExit: () => Navigator.pop(context),   // optional: shows a back button
  language: 'es',                         // optional: start in Spanish
)
```

## Parameters

| Parameter | Required | Meaning |
| --- | --- | --- |
| `playerId` | yes | Any stable string for the child, e.g. the host's PIN. All progress is stored under it. |
| `playerName` | no | Shown in the greeting. No greeting when omitted. |
| `onNewBest` | no | Called when the child beats their own best round in a game. |
| `onExit` | no | Adds a back button to the home screen that calls this. |
| `language` | no | `'en'` or `'es'`. Defaults to English; children can switch on the home screen. |

`VocabGame` builds its own `MaterialApp` (theme and navigation), so it can be
pushed as a route or placed anywhere in the host's widget tree. Changing
`playerId` restarts the game for the new player.

## Scores

`onNewBest` receives a `NewBest`:

| Field | Example |
| --- | --- |
| `playerId` | `'123'` |
| `game` | `'bubble_pop'` (stable key: `picture_quiz`, `bubble_pop`, `memory_match`) |
| `gameName` | `'Bubble Pop'` |
| `score` | `140` |

It fires only when a score beats that child's previous best in that game.
The game keeps its own points, levels and bests on the device; the host
decides whether and where to store the reported best. Errors thrown by the
callback are logged and never interrupt the game.

## Data

Everything is stored per `playerId` in a local SQLite database:

- `answers`: every answer (word, choice, correct, response time, language).
  Per-word learning state is derived from this log.
- `rounds`: every finished round (game, group, points), for totals and bests.

## Web hosts

On the web, SQLite runs as WebAssembly. A host app built for the web also
needs `web/sqlite3.wasm` and `web/sqflite_sw.js` from this project in its own
`web/` folder.

## Trying several players without a host

When the app runs on its own, a name in the link selects the player:
`http://localhost:8081/?kid=mia`. This is a testing shortcut, not a login.
Without it, everyone shares one default player.
