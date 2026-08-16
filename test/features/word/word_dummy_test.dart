import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/word/data/datasources/word_local_data_source.dart';
import 'package:goodquestion/features/word/data/repositories/word_repository_mock.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/sentence_practice.dart';
import 'package:goodquestion/features/word/domain/entities/word_book.dart';
import 'package:goodquestion/features/word/domain/entities/word_group.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WordRepositoryMock repositoryOf() =>
      WordRepositoryMock(const WordLocalDataSource(), latency: Duration.zero);

  test('단어장 더미(WordResponse 목록)가 이야기 그룹으로 파싱된다', () async {
    final WordBook book = await repositoryOf().getWordBook();

    expect(book.groups, isNotEmpty);
    // 그룹이 하나뿐이면 "이야기별로 묶인다"는 게 시연되지 않습니다.
    expect(book.groups.length, greaterThanOrEqualTo(2));
    for (final WordGroup group in book.groups) {
      expect(group.storyId, isNotEmpty);
      expect(group.storyTitle, isNotEmpty);
      expect(group.words, isNotEmpty);
      for (final SavedWord word in group.words) {
        expect(word.wordId, isNotEmpty);
        expect(word.word, isNotEmpty);
        // 뜻과 이야기 예문은 목록에 안 나오지만 모달이 반드시 씁니다.
        expect(word.meaning, isNotNull);
        expect(word.meaning, isNotEmpty);
        expect(word.sentenceStory, isNotNull);
        expect(word.sentenceStory, isNotEmpty);
      }
    }
  });

  test('총 개수가 실제 단어 수와 맞는다', () async {
    final WordBook book = await repositoryOf().getWordBook();
    final int counted = book.groups.fold(
      0,
      (int sum, WordGroup g) => sum + g.words.length,
    );

    expect(book.totalCount, counted, reason: '헤더 배지 숫자가 목록과 어긋납니다');
  });

  test('예문 확장 전에 담은 단어(일상/심화 없음)가 더미에 있다', () async {
    // EXAMPLE_SENTENCE_MISSING 분기를 미리보기에서 볼 수 있어야 합니다.
    final WordBook book = await repositoryOf().getWordBook();
    final List<SavedWord> words = book.groups
        .expand((WordGroup g) => g.words)
        .toList(growable: false);

    expect(
      words.any(
        (SavedWord w) => w.sentenceDaily == null && w.sentenceAdvanced == null,
      ),
      isTrue,
    );
    // 그래도 따라 말하기 자체는 이야기 예문으로 가능해야 합니다.
    expect(words.every((SavedWord w) => w.hasPracticeSentence), isTrue);
  });

  test('좋아요를 토글하면 다음 조회에 반영된다', () async {
    final WordRepositoryMock repository = repositoryOf();
    final WordBook before = await repository.getWordBook();
    final SavedWord target = before.groups.first.words.first;

    final bool next = await repository.toggleLike(target.wordId);

    expect(next, !target.liked);
    final WordBook after = await repository.getWordBook();
    final SavedWord updated = after.groups
        .expand((WordGroup g) => g.words)
        .firstWhere((SavedWord w) => w.wordId == target.wordId);
    expect(updated.liked, next);
  });

  test('목업 따라 말하기 - 처음엔 보상, 같은 문장은 ALREADY_REWARDED', () async {
    final WordRepositoryMock repository = repositoryOf();
    final WordBook book = await repository.getWordBook();
    final SavedWord target = book.groups.first.words.first;

    final SentencePracticeResult first = await repository.practiceSentence(
      wordId: target.wordId,
      sentenceType: SentenceType.story,
      spokenText: target.sentenceStory!,
    );
    expect(first.rewarded, isTrue);
    expect(first.stardustAmount, 2);

    final SentencePracticeResult second = await repository.practiceSentence(
      wordId: target.wordId,
      sentenceType: SentenceType.story,
      spokenText: target.sentenceStory!,
    );
    expect(second.rewarded, isFalse);
    expect(second.skipReason, SentencePracticeSkipReason.alreadyRewarded);
    expect(second.stardustBalance, first.stardustBalance);
  });
}
