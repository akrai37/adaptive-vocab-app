import '../models/word.dart';
import 'selector.dart';
import 'stats.dart';

/// Plain-English reasons for what the app chose, shown to teachers in demo
/// mode. Children never see these.

/// Why [pick] was chosen.
String explainPick(Pick pick, WordStats? s, DateTime now) {
  switch (pick.reason) {
    case PickReason.struggling:
      return 'Easy one: 2 of the last 3 answers were wrong';
    case PickReason.unseen:
      return 'New word';
    case PickReason.reviewAhead:
      return 'Extra practice: nothing else is due';
    case PickReason.overdue:
      final since = ago(now.difference(s!.lastSeen!));
      if (s.graded == 0) {
        return 'Practise it: seen (Cards or Memory) $since ago';
      }
      if (s.streak == 0) return 'Brought back: missed $since ago';
      return 'Due for review: last seen $since ago (box ${s.box})';
  }
}

/// How hard the wrong answers for [target] are, and why.
String explainOptions(
  Word target,
  List<Word> wrong,
  WordStats? s,
  String lang,
) {
  if (s == null || s.box < knownBox) {
    return 'Easy choices: from other groups (box ${s?.box ?? 0})';
  }
  final mixUps = wrong
      .where((w) => s.confusions.containsKey(w.id))
      .map((w) => w.label(lang))
      .toList();
  final base = 'Hard choices: same group (box ${s.box})';
  return mixUps.isEmpty
      ? base
      : '$base, includes past mix-up: ${mixUps.join(', ')}';
}

/// Where [word] sits in a Cards round, and why.
String explainCard(WordStats? s) {
  if (s == null) return 'Not seen yet';
  if (s.box >= knownBox) return 'Known well (box ${s.box}), so shown late';
  if (s.missed > 0) {
    return 'Shown early: missed ${s.missed} time${s.missed == 1 ? '' : 's'}';
  }
  return 'Still learning (box ${s.box})';
}

/// "40 s", "3 min", "5 h", "2 days".
String ago(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 48) return '${d.inHours} h';
  return '${d.inDays} days';
}
