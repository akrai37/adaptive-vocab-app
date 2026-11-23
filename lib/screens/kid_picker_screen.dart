import 'package:flutter/material.dart';

import '../config.dart';
import '../data/answer_log.dart';
import '../data/learner_store.dart';
import '../data/session.dart';
import '../data/speaker.dart';
import '../data/word_repository.dart';
import '../models/learner.dart';
import '../theme.dart';
import '../widgets/word_picture.dart';
import 'home_screen.dart';
import 'teacher_screen.dart';

/// Pictures a child can choose as their avatar (word ids from the word list).
const avatarChoices = [
  'cat', 'dog', 'cow', 'pig', 'duck', 'hen', //
  'fish', 'bird', 'flower', 'star', 'sun', 'tree',
];

/// Each child taps their own avatar. No passwords; adding a child needs the
/// teacher code.
///
/// PARKED (2026-11-09): not wired into the app yet; it opens straight to
/// [HomeScreen] as one shared learner. Turn on by using this as `home:` in
/// main.dart.
class KidPickerScreen extends StatefulWidget {
  final WordRepository words;
  final AnswerLog log;
  final LearnerStore learners;
  final Speaker speaker;

  const KidPickerScreen({
    super.key,
    required this.words,
    required this.log,
    required this.learners,
    required this.speaker,
  });

  @override
  State<KidPickerScreen> createState() => _KidPickerScreenState();
}

class _KidPickerScreenState extends State<KidPickerScreen> {
  List<Learner>? _kids;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kids = await widget.learners.all();
    if (mounted) setState(() => _kids = kids);
  }

  Future<void> _open(Learner kid) async {
    final session = await Session.start(
      words: widget.words,
      log: widget.log,
      learnerId: kid.id,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HomeScreen(session: session, speaker: widget.speaker, learner: kid),
      ),
    );
  }

  Future<void> _addKid() async {
    if (!await askTeacherCode(context) || !mounted) return;
    final used = {for (final k in _kids ?? const <Learner>[]) k.avatar};
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AddKidDialog(words: widget.words, used: used),
    );
    if (result == null) return;
    await widget.learners.add(name: result.$1, avatar: result.$2);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final kids = _kids;
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'build $buildLabel',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      appBar: AppBar(title: const Text("Who's playing?")),
      body: kids == null
          ? const Center(child: CircularProgressIndicator())
          : GridView.extent(
              maxCrossAxisExtent: 240,
              padding: const EdgeInsets.all(24),
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              children: [
                for (var i = 0; i < kids.length; i++)
                  BigTile(
                    key: ValueKey(kids[i].id),
                    color: kidColor(i),
                    onTap: () => _open(kids[i]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Avatar(widget.words, kids[i].avatar, size: 96),
                        const SizedBox(height: 10),
                        Text(
                          kids[i].name,
                          style: wordStyle(size: 28, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                BigTile(
                  color: Colors.white,
                  onTap: _addKid,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 72, color: ink),
                      Text('Add a kid', style: wordStyle(size: 24)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A child's avatar: their chosen picture in a white circle.
class Avatar extends StatelessWidget {
  final WordRepository words;
  final String avatar;
  final double size;

  const Avatar(this.words, this.avatar, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final word = words.words.where((w) => w.id == avatar).firstOrNull;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: word == null
          ? Icon(Icons.face_rounded, size: size * 0.6, color: ink)
          : WordPicture(word, size: size * 0.7),
    );
  }
}

/// Teacher enters a name and the child picks a picture.
class _AddKidDialog extends StatefulWidget {
  final WordRepository words;

  /// Avatars already taken; the first free one is preselected.
  final Set<String> used;

  const _AddKidDialog({required this.words, required this.used});

  @override
  State<_AddKidDialog> createState() => _AddKidDialogState();
}

class _AddKidDialogState extends State<_AddKidDialog> {
  final _name = TextEditingController();
  late String _avatar = avatarChoices.firstWhere(
    (a) => !widget.used.contains(a),
    orElse: () => avatarChoices.first,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, (_name.text.trim(), _avatar));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a kid'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 16,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in avatarChoices)
                InkWell(
                  key: ValueKey('avatar-$a'),
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _avatar = a),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 4,
                        color: a == _avatar
                            ? const Color(0xFFFF8A3D)
                            : Colors.transparent,
                      ),
                    ),
                    child: Avatar(widget.words, a, size: 56),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Add')),
    ],
  );
}
