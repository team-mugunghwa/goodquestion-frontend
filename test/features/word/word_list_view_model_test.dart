import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/sentence_practice.dart';
import 'package:goodquestion/features/word/domain/entities/word_book.dart';
import 'package:goodquestion/features/word/domain/entities/word_group.dart';
import 'package:goodquestion/features/word/domain/repositories/word_repository.dart';
import 'package:goodquestion/features/word/domain/usecases/get_word_book_use_case.dart';
import 'package:goodquestion/features/word/domain/usecases/toggle_word_like_use_case.dart';
import 'package:goodquestion/features/word/presentation/viewmodels/word_list_view_model.dart';

class _StubRepository implements WordRepository {
  _StubRepository({this.book, this.error});

  final WordBook? book;
  final Object? error;
  final Map<String, bool> likes = <String, bool>{};

  @override
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  }) async => throw UnimplementedError();

  @override
  Future<String> transcribe(Uint8List wavBytes) async =>
      throw UnimplementedError();

  @override
  Future<WordBook> getWordBook() async {
    if (error != null) throw error!;
    return book!;
  }

  @override
  Future<bool> toggleLike(String wordId) async {
    final bool next = !(likes[wordId] ?? false);
    likes[wordId] = next;
    return next;
  }
}

const WordBook _book = WordBook(
  totalCount: 3,
  childName: '하늘이',
  groups: <WordGroup>[
    WordGroup(
      storyId: '11',
      storyTitle: '방귀 뀌는 며느리',
      words: <SavedWord>[
        SavedWord(
          wordId: '101',
          word: '며느리',
          meaning: '아들과 결혼한 사람이에요.',
          sentence: '며느리가 살았어요.',
          liked: false,
        ),
        SavedWord(
          wordId: '102',
          word: '사랑방',
          meaning: '손님을 맞이하는 방이에요.',
          sentence: '사랑방에서 만났어요.',
          liked: false,
        ),
      ],
    ),
    WordGroup(
      storyId: '21',
      storyTitle: '해와 달이 된 오누이',
      words: <SavedWord>[
        SavedWord(
          wordId: '201',
          word: '오누이',
          meaning: '오빠와 여동생이에요.',
          sentence: '오누이가 남았어요.',
          liked: true,
        ),
      ],
    ),
  ],
);

const WordBook _emptyBook = WordBook(totalCount: 0, groups: <WordGroup>[]);

void main() {
  WordListViewModel viewModelOf(WordRepository repository) => WordListViewModel(
    GetWordBookUseCase(repository),
    ToggleWordLikeUseCase(repository),
  );

  test('load 하면 이야기 그룹이 그대로 온다', () async {
    final vm = viewModelOf(_StubRepository(book: _book));

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.visibleGroups, hasLength(2));
    expect(vm.totalCount, 3);
    expect(vm.isEmpty, isFalse);
  });

  test('이야기를 고르면 그 그룹만 남는다', () async {
    final vm = viewModelOf(_StubRepository(book: _book));
    await vm.load();

    vm.selectStory('21');

    expect(vm.visibleGroups, hasLength(1));
    expect(vm.visibleGroups.first.storyTitle, '해와 달이 된 오누이');
  });

  test('전체로 되돌리면 다시 다 보인다', () async {
    final vm = viewModelOf(_StubRepository(book: _book));
    await vm.load();
    vm.selectStory('21');

    vm.selectStory(WordListViewModel.allStoryId);

    expect(vm.visibleGroups, hasLength(2));
  });

  test('담은 단어가 없으면 필터 결과 0건과 다른 상태다', () async {
    final vm = viewModelOf(_StubRepository(book: _emptyBook));

    await vm.load();

    // 하나는 "이야기 하러 가기", 다른 하나는 "전체 보기"로 안내가 달라집니다.
    expect(vm.isEmpty, isTrue);
    expect(vm.isEmptyByFilter, isFalse);
  });

  test('좋아요가 목록 카드에 즉시 반영된다', () async {
    final vm = viewModelOf(_StubRepository(book: _book));
    await vm.load();

    await vm.toggleLike('101');

    expect(vm.wordOf('101')?.liked, isTrue);
    // 다른 단어는 건드리지 않습니다.
    expect(vm.wordOf('102')?.liked, isFalse);
    expect(vm.wordOf('201')?.liked, isTrue);
  });

  test('실패하면 error 와 메시지가 남는다', () async {
    final vm = viewModelOf(
      _StubRepository(error: const NetworkFailure('연결이 끊겼습니다.')),
    );

    await vm.load();

    expect(vm.state, ViewState.error);
    expect(vm.errorMessage, '연결이 끊겼습니다.');
  });
}
