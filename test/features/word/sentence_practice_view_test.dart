import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/sentence_practice.dart';
import 'package:goodquestion/features/word/domain/entities/word_book.dart';
import 'package:goodquestion/features/word/domain/repositories/word_repository.dart';
import 'package:goodquestion/features/word/presentation/viewmodels/sentence_practice_view_model.dart';
import 'package:goodquestion/features/word/presentation/views/sentence_practice_view.dart';
import 'package:provider/provider.dart';

class _FakeRepository implements WordRepository {
  _FakeRepository({this.practiceResult});

  final SentencePracticeResult? practiceResult;

  @override
  Future<WordBook> getWordBook() async =>
      WordBook.fromWords(const <SavedWord>[_word]);

  @override
  Future<bool> toggleLike(String wordId) async => true;

  @override
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  }) async => practiceResult!;

  @override
  Future<String> transcribe(Uint8List wavBytes) async => '따라 말한 문장';
}

const SavedWord _word = SavedWord(
  wordId: 'w101',
  word: '며느리',
  meaning: '아들과 결혼한 사람이에요.',
  sentenceStory: '옛날에 며느리가 살았어요.',
  sentenceDaily: '할머니 댁에서 이야기를 들었어요.',
  liked: false,
);

void main() {
  Future<SentencePracticeViewModel> pump(
    WidgetTester tester,
    WordRepository repository, {
    Size size = const Size(1280, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final SentencePracticeViewModel vm = SentencePracticeViewModel(
      repository,
      wordId: _word.wordId,
      initialWord: _word,
    );
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider<SentencePracticeViewModel>.value(
          value: vm,
          child: const SentencePracticeView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('있는 예문만 카드로 고르게 한다', (WidgetTester tester) async {
    await pump(tester, _FakeRepository());

    expect(find.text(SentencePracticeStrings.pickGuide), findsOneWidget);
    expect(find.text(SentencePracticeStrings.typeStory), findsOneWidget);
    expect(find.text(SentencePracticeStrings.typeDaily), findsOneWidget);
    // advanced 예문이 없는 단어라 심화 카드는 없어야 합니다.
    expect(find.text(SentencePracticeStrings.typeAdvanced), findsNothing);
    expect(find.text('옛날에 며느리가 살았어요.'), findsOneWidget);
  });

  testWidgets('예문을 고르면 큰 문장과 마이크가 뜬다', (WidgetTester tester) async {
    await pump(tester, _FakeRepository());

    await tester.tap(find.text('옛날에 며느리가 살았어요.'));
    await tester.pumpAndSettle();

    expect(find.text(SentencePracticeStrings.speakGuide), findsOneWidget);
    expect(find.text(SentencePracticeStrings.micReady), findsOneWidget);
    expect(
      find.bySemanticsLabel(SentencePracticeStrings.micStart),
      findsOneWidget,
    );
  });

  testWidgets('보상 결과가 별가루와 함께 그려진다', (WidgetTester tester) async {
    final SentencePracticeViewModel vm = await pump(
      tester,
      _FakeRepository(
        practiceResult: const SentencePracticeResult(
          matched: true,
          similarity: 0.97,
          targetSentence: '옛날에 며느리가 살았어요.',
          rewarded: true,
          stardustAmount: 2,
          stardustBalance: 12,
        ),
      ),
    );

    vm.selectSentence(SentenceType.story);
    vm.beginRecording();
    await vm.submitRecording(Uint8List.fromList(List<int>.filled(64, 1)));
    await tester.pumpAndSettle();

    expect(find.text(SentencePracticeStrings.rewardedTitle), findsOneWidget);
    expect(find.text(SentencePracticeStrings.stardustGain(2)), findsOneWidget);
    expect(find.text('12'), findsOneWidget, reason: '갱신된 잔액이 칩에 떠야 합니다');
    expect(find.text(SentencePracticeStrings.anotherSentence), findsOneWidget);
    expect(find.text(SentencePracticeStrings.backToWords), findsOneWidget);
  });

  testWidgets('90% 미만이면 닮은 정도와 두 문장을 보여 준다', (WidgetTester tester) async {
    final SentencePracticeViewModel vm = await pump(
      tester,
      _FakeRepository(
        practiceResult: const SentencePracticeResult(
          matched: false,
          similarity: 0.6,
          targetSentence: '옛날에 며느리가 살았어요.',
          rewarded: false,
          stardustAmount: 0,
          stardustBalance: 10,
        ),
      ),
    );

    vm.selectSentence(SentenceType.story);
    vm.beginRecording();
    await vm.submitRecording(Uint8List.fromList(List<int>.filled(64, 1)));
    await tester.pumpAndSettle();

    expect(find.text(SentencePracticeStrings.notMatchedTitle), findsOneWidget);
    expect(find.text(SentencePracticeStrings.similarity(60)), findsOneWidget);
    expect(find.text('옛날에 며느리가 살았어요.'), findsOneWidget);
    expect(find.text('따라 말한 문장'), findsOneWidget);
    expect(find.text(SentencePracticeStrings.retry), findsOneWidget);
  });

  testWidgets('폰 폭에서도 레이아웃이 무너지지 않는다', (WidgetTester tester) async {
    final SentencePracticeViewModel vm = await pump(
      tester,
      _FakeRepository(),
      size: const Size(390, 844),
    );

    vm.selectSentence(SentenceType.story);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
