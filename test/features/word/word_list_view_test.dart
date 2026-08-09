import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/word_book.dart';
import 'package:goodquestion/features/word/domain/entities/word_group.dart';
import 'package:goodquestion/features/word/domain/repositories/word_repository.dart';
import 'package:goodquestion/features/word/domain/usecases/get_word_book_use_case.dart';
import 'package:goodquestion/features/word/domain/usecases/toggle_word_like_use_case.dart';
import 'package:goodquestion/features/word/presentation/viewmodels/word_list_view_model.dart';
import 'package:goodquestion/features/word/presentation/views/word_list_view.dart';
import 'package:goodquestion/features/word/presentation/widgets/word_card.dart';
import 'package:provider/provider.dart';

class _StubRepository implements WordRepository {
  _StubRepository({this.book, this.error});

  final WordBook? book;
  final Object? error;
  final Map<int, bool> likes = <int, bool>{};

  @override
  Future<WordBook> getWordBook() async {
    if (error != null) throw error!;
    return book!;
  }

  @override
  Future<bool> toggleLike(int wordId) async {
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
      storyId: 11,
      storyTitle: '방귀 뀌는 며느리',
      words: <SavedWord>[
        SavedWord(
          wordId: 101,
          word: '며느리',
          meaning: '아들과 결혼한 사람이에요.',
          sentence: '며느리가 살았어요.',
          liked: false,
        ),
        SavedWord(
          wordId: 102,
          word: '사랑방',
          meaning: '손님을 맞이하는 방이에요.',
          sentence: '사랑방에서 만났어요.',
          liked: false,
        ),
      ],
    ),
    WordGroup(
      storyId: 21,
      storyTitle: '해와 달이 된 오누이',
      words: <SavedWord>[
        SavedWord(
          wordId: 201,
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
  Future<void> pump(
    WidgetTester tester,
    WordRepository repository, {
    Size size = const Size(1280, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider<WordListViewModel>(
          create: (_) => WordListViewModel(
            GetWordBookUseCase(repository),
            ToggleWordLikeUseCase(repository),
          )..load(),
          child: const WordListView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('이야기 그룹 헤더 아래에 단어 카드가 놓인다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _book));

    expect(find.text(WordStrings.title), findsOneWidget);
    // 그룹 헤더와 필터 칩 양쪽에 이야기 제목이 나옵니다.
    expect(find.text('방귀 뀌는 며느리'), findsWidgets);
    expect(find.byType(WordCard), findsNWidgets(3));
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('목록에는 뜻과 예문이 나오지 않는다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _book));

    // 목록은 밀도가 낮아야 합니다 — 뜻은 모달의 몫입니다. (PRD F-10)
    expect(find.text('아들과 결혼한 사람이에요.'), findsNothing);
    expect(find.text('며느리가 살았어요.'), findsNothing);
  });

  testWidgets('단어를 누르면 뜻·예문 모달이 열린다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _book));

    await tester.tap(find.text('며느리').last);
    await tester.pumpAndSettle();

    expect(find.text(WordStrings.meaning), findsOneWidget);
    expect(find.text('아들과 결혼한 사람이에요.'), findsOneWidget);
    expect(find.text('며느리가 살았어요.'), findsOneWidget);
  });

  testWidgets('모달에서 좋아요를 바꾸면 목록 카드에 반영된다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _book));
    await tester.tap(find.text('며느리').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(WordStrings.like));
    await tester.pumpAndSettle();
    await tester.tap(find.text(WordStrings.close));
    await tester.pumpAndSettle();

    final WordCard card = tester.widget<WordCard>(find.byType(WordCard).first);
    expect(card.word.liked, isTrue);
  });

  testWidgets('이야기 칩으로 그룹을 좁힌다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _book));

    await tester.tap(find.text('해와 달이 된 오누이').first);
    await tester.pumpAndSettle();

    expect(find.byType(WordCard), findsNWidgets(1));
  });

  testWidgets('담은 단어가 없으면 이야기로 보낸다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(book: _emptyBook));

    expect(find.text(WordStrings.goToStories), findsOneWidget);
    // 거를 것이 없으면 칩도 숨깁니다.
    expect(find.text(AppStrings.filterAll), findsNothing);
  });

  testWidgets('실패하면 다시 불러오기 버튼이 뜬다', (WidgetTester tester) async {
    await pump(tester, _StubRepository(error: const NetworkFailure()));

    expect(find.text(AppStrings.retryKid), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('폰 폭에서도 레이아웃이 무너지지 않는다', (WidgetTester tester) async {
    await pump(
      tester,
      _StubRepository(book: _book),
      size: const Size(390, 844),
    );

    expect(find.byType(WordCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
