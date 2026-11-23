// Languages (English, Spanish) and on-screen text: see l10n.dart.

/// Local passcode for the teacher screen. Not an account; just keeps children
/// out. TODO: let the teacher change it.
const teacherPasscode = '1234';

/// Questions or cards per round.
const roundLength = 8;

/// Shown small on the home screen so it's clear which build is running.
/// Set at build time: `flutter build web --dart-define=BUILD=<label>`.
const buildLabel = String.fromEnvironment('BUILD', defaultValue: 'dev');

/// Pseudo-category for "Mix everything": a round with words from every group.
const mixCategory = 'mix';

/// Bubble Pop: length of a round, and how long bubbles take to float up
/// (starts slow, gets faster with each right answer, never below the min).
const bubbleRoundTime = Duration(seconds: 60);
const bubbleRiseStart = Duration(milliseconds: 7000);
const bubbleRiseMin = Duration(milliseconds: 4000);
const bubbleRiseStep = Duration(milliseconds: 250);

/// Player id used when nobody says who is playing (no PIN from a host app,
/// no ?kid= in the link). Everyone on the device shares it.
const defaultPlayer = 'anon';

/// Memory: pairs per round (each pair = a picture card and its word card).
const memoryPairs = 6;
