import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/answer_log.dart';
import 'package:vocab_app/models/answer.dart';

void main() {
  sqfliteFfiInit();

  late AnswerLog log;
  setUp(() async {
    log = await AnswerLog.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => log.close());

  Answer answer(String word, String chosen, int t, {String learner = 'anon'}) =>
      Answer(
        learnerId: learner,
        activityType: 'picture_quiz',
        wordId: word,
        chosen: chosen,
        correct: word == chosen,
        latencyMs: 1200,
        timestamp: DateTime.fromMillisecondsSinceEpoch(t),
      );

  test('stores answers and returns them oldest first', () async {
    await log.add(answer('apple', 'orange', 2000));
    await log.add(answer('cat', 'cat', 1000));

    final all = await log.all();
    expect(all.map((a) => a.wordId), ['cat', 'apple']);
    expect(all[1].chosen, 'orange');
    expect(all[1].correct, isFalse);
    expect(all[0].correct, isTrue);
    expect(all[0].learnerId, 'anon');
  });

  test('keeps learners separate', () async {
    await log.add(answer('cat', 'cat', 1000));
    await log.add(answer('dog', 'dog', 1000, learner: 'kid1'));

    expect(await log.all(), hasLength(1));
    expect(await log.all(learnerId: 'kid1'), hasLength(1));
  });
}
