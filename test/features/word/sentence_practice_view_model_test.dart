import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/sentence_practice.dart';
import 'package:goodquestion/features/word/domain/entities/word_book.dart';
import 'package:goodquestion/features/word/domain/repositories/word_repository.dart';
import 'package:goodquestion/features/word/presentation/viewmodels/sentence_practice_view_model.dart';

/// 시나리오를 갈아 끼울 수 있는 가짜 저장소.
class _FakeRepository implements WordRepository {
  _FakeRepository({
    this.book,
    this.practiceResult,
    this.practiceError,
    this.transcribeError,
  });

  WordBook? book;
  SentencePracticeResult? practiceResult;
  Object? practiceError;
  String transcribed = '따라 말한 문장';
  Object? transcribeError;
  int practiceCalls = 0;

  @override
  Future<WordBook> getWordBook() async => book!;

  @override
  Future<bool> toggleLike(String wordId) async => true;

  @override
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  }) async {
    practiceCalls++;
    if (practiceError != null) throw practiceError!;
    return practiceResult!;
  }

  @override
  Future<String> transcribe(Uint8List wavBytes) async {
    if (transcribeError != null) throw transcribeError!;
    return transcribed;
  }
}

const SavedWord _word = SavedWord(
  wordId: 'w101',
  word: '며느리',
  meaning: '아들과 결혼한 사람이에요.',
  sentenceStory: '옛날에 며느리가 살았어요.',
  sentenceDaily: '할머니 댁에서 이야기를 들었어요.',
  liked: false,
);

SentencePracticeResult _result({
  bool matched = true,
  double similarity = 0.95,
  bool rewarded = false,
  SentencePracticeSkipReason? skipReason,
  int amount = 0,
  int balance = 10,
}) => SentencePracticeResult(
  matched: matched,
  similarity: similarity,
  targetSentence: _word.sentenceStory!,
  rewarded: rewarded,
  skipReason: skipReason,
  stardustAmount: amount,
  stardustBalance: balance,
);

void main() {
  final Uint8List wav = Uint8List.fromList(List<int>.filled(64, 1));

  SentencePracticeViewModel viewModelOf(_FakeRepository repository) =>
      SentencePracticeViewModel(
        repository,
        wordId: _word.wordId,
        initialWord: _word,
      );

  /// 예문을 고르고 녹음 한 번을 끝까지 흉내 냅니다.
  Future<void> speakOnce(SentencePracticeViewModel vm) async {
    vm.selectSentence(SentenceType.story);
    vm.beginRecording();
    await vm.submitRecording(wav);
  }

  test('extra 로 받은 단어면 서버를 부르지 않고 바로 고르기 단계다', () async {
    final vm = viewModelOf(_FakeRepository());

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.step, PracticeStep.pick);
    // story 와 daily 만 있고 advanced 는 없습니다.
    expect(vm.sentences, hasLength(2));
    expect(vm.sentences.first.type, SentenceType.story);
  });

  test('딥링크로 들어오면 단어장을 뒤져 단어를 찾는다', () async {
    final repository = _FakeRepository(
      book: WordBook.fromWords(const <SavedWord>[_word]),
    );
    final vm = SentencePracticeViewModel(repository, wordId: _word.wordId);

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.word?.word, '며느리');
  });

  test('90% 이상 + 보상 -> rewarded 결과', () async {
    final vm = viewModelOf(
      _FakeRepository(
        practiceResult: _result(rewarded: true, amount: 2, balance: 12),
      ),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.step, PracticeStep.result);
    expect(vm.resultKind, PracticeResultKind.rewarded);
    expect(vm.result?.stardustAmount, 2);
    expect(vm.result?.stardustBalance, 12);
    expect(vm.spokenText, '따라 말한 문장');
  });

  test('맞았지만 이미 받은 문장 -> alreadyRewarded', () async {
    final vm = viewModelOf(
      _FakeRepository(
        practiceResult: _result(
          skipReason: SentencePracticeSkipReason.alreadyRewarded,
        ),
      ),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.resultKind, PracticeResultKind.alreadyRewarded);
  });

  test('맞았지만 오늘 한도 초과 -> dailyLimit', () async {
    final vm = viewModelOf(
      _FakeRepository(
        practiceResult: _result(
          skipReason: SentencePracticeSkipReason.dailyLimit,
        ),
      ),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.resultKind, PracticeResultKind.dailyLimit);
  });

  test('90% 미만 -> notMatched, 다시 말하기로 돌아갈 수 있다', () async {
    final vm = viewModelOf(
      _FakeRepository(practiceResult: _result(matched: false, similarity: 0.6)),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.resultKind, PracticeResultKind.notMatched);
    expect(vm.result?.similarityPercent, 60);

    vm.speakAgain();

    expect(vm.step, PracticeStep.speak);
    expect(vm.selectedType, SentenceType.story, reason: '같은 문장을 다시 합니다');
    expect(vm.result, isNull);
  });

  test('EXAMPLE_SENTENCE_MISSING -> sentenceMissing 결과', () async {
    final vm = viewModelOf(
      _FakeRepository(
        practiceError: const ServerFailure(
          message: '예문이 없습니다.',
          code: 'EXAMPLE_SENTENCE_MISSING',
        ),
      ),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.resultKind, PracticeResultKind.sentenceMissing);

    vm.backToPick();

    expect(vm.step, PracticeStep.pick);
    expect(vm.selectedType, isNull);
  });

  test('네트워크 실패 -> failed, resubmit 이 같은 문장으로 다시 보낸다', () async {
    final repository = _FakeRepository(
      practiceError: const NetworkFailure('연결이 끊겼습니다.'),
    );
    final vm = viewModelOf(repository);
    await vm.load();

    await speakOnce(vm);

    expect(vm.resultKind, PracticeResultKind.failed);
    expect(vm.failureMessage, '연결이 끊겼습니다.');
    expect(repository.practiceCalls, 1);

    // 네트워크가 돌아온 뒤 다시 보내면 - 아이가 또 말할 필요가 없습니다.
    repository
      ..practiceError = null
      ..practiceResult = _result(rewarded: true, amount: 2, balance: 12);
    await vm.resubmit();

    expect(repository.practiceCalls, 2);
    expect(vm.resultKind, PracticeResultKind.rewarded);
  });

  test('받아쓰기가 비었으면 결과로 가지 않고 마이크 옆 안내만 띄운다', () async {
    final vm = viewModelOf(
      _FakeRepository(transcribeError: const UnknownFailure('빈 음성')),
    );
    await vm.load();

    await speakOnce(vm);

    expect(vm.step, PracticeStep.speak, reason: '화면 전체를 에러로 바꾸지 않습니다');
    expect(vm.voiceStage, PracticeVoiceStage.ready);
    expect(vm.micHint, PracticeMicHint.notHeard);
  });

  test('녹음이 비어 있으면 서버를 부르지 않는다', () async {
    final repository = _FakeRepository(practiceResult: _result());
    final vm = viewModelOf(repository);
    await vm.load();
    vm.selectSentence(SentenceType.story);
    vm.beginRecording();

    await vm.submitRecording(null);

    expect(vm.micHint, PracticeMicHint.notHeard);
    expect(repository.practiceCalls, 0);
  });
}
