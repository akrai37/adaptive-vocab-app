import 'package:flutter/material.dart';

import '../config.dart';
import '../data/session.dart';
import '../logic/stats.dart';
import '../models/word.dart';
import '../widgets/word_picture.dart';

/// Asks for the teacher passcode; true if it was entered correctly.
Future<bool> askTeacherCode(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _PasscodeDialog(),
    ) ==
    true;

/// Asks for the passcode, then opens [TeacherScreen] if it matches.
Future<void> openTeacher(BuildContext context, Session session) async {
  if (await askTeacherCode(context) && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeacherScreen(session: session)),
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog's closing
/// animation finishes.
class _PasscodeDialog extends StatefulWidget {
  const _PasscodeDialog();

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text == teacherPasscode);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Teacher code'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      maxLength: 4,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Open')),
    ],
  );
}

/// Every word, worst first: lowest box, then most misses. Words never
/// practised go last.
class TeacherScreen extends StatelessWidget {
  final Session session;

  const TeacherScreen({super.key, required this.session});

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset points for every child?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await session.resetAllPoints();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Points reset.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = session.stats;
    final words = worstFirst(session.words.words, stats);
    return Scaffold(
      appBar: AppBar(title: const Text('Words to work on')),
      body: ListView(
        children: [
          StatefulBuilder(
            builder: (context, setState) => SwitchListTile(
              secondary: const Icon(Icons.lightbulb_outline_rounded),
              title: const Text('Show why (demo mode)'),
              subtitle: const Text(
                'Games explain why each word and its choices were picked. '
                'Turn off before children play.',
              ),
              value: session.showWhy,
              onChanged: (v) => setState(() => session.showWhy = v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset points'),
            subtitle: const Text(
              'Points, levels and best scores go back to 0 for every child. '
              'What they have learned is kept.',
            ),
            onTap: () => _confirmReset(context),
          ),
          const Divider(),
          for (final w in words) _row(w, stats[w.id]),
        ],
      ),
    );
  }

  Widget _row(Word w, WordStats? s) {
    final graded = s?.graded ?? 0;
    final confusion = s == null || s.confusions.isEmpty
        ? null
        : (s.confusions.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    return ListTile(
      leading: WordPicture(w, size: 32),
      title: Text(w.label(session.language)),
      subtitle: Text(
        graded == 0
            ? 'Not practised yet'
            : 'Missed ${s!.missed} of $graded'
                  '${confusion == null ? '' : ' · mixes up with ${session.words.byId(confusion).label(session.language)}'}',
      ),
      trailing: Text(s == null ? '' : 'Box ${s.box} of 4'),
    );
  }
}

List<Word> worstFirst(List<Word> words, Map<String, WordStats> stats) {
  int practised(Word w) => (stats[w.id]?.graded ?? 0) > 0 ? 0 : 1;
  return [...words]..sort((a, b) {
    final p = practised(a).compareTo(practised(b));
    if (p != 0) return p;
    final sa = stats[a.id], sb = stats[b.id];
    if (sa == null || sb == null) return 0;
    final box = sa.box.compareTo(sb.box);
    return box != 0 ? box : sb.missed.compareTo(sa.missed);
  });
}
