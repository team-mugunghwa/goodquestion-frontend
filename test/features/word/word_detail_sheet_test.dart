import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/widgets/screen_metrics.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/presentation/widgets/word_detail_sheet.dart';

/// 단어 상세 모달의 예문 3종(이야기/일상/심화) 표시.
///
/// 서버 예문 3종 체계(V14) 이후 담긴 단어는 세 칸이 다 보이고, 그 전에
/// 담긴 단어(일상/심화 null)는 이야기 칸만 보여야 한다 - 빈 제목만 있는
/// 칸이 뜨면 아이가 고장으로 읽는다.
void main() {
  Future<void> open(WidgetTester tester, SavedWord word) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showWordDetailSheet(
                  context,
                  word: word,
                  metrics: ScreenMetrics.of(800),
                  onToggleLike: () async {},
                  latest: () => word,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('예문 3종이 있으면 세 칸을 모두 보여준다', (WidgetTester tester) async {
    await open(
      tester,
      const SavedWord(
        wordId: 'w-1',
        word: '기왓장',
        meaning: '지붕을 덮는 납작한 조각',
        sentence: '방귀 소리에 지붕의 기왓장이 들썩들썩 움직였어요.',
        sentenceDaily: '한옥 지붕은 기왓장을 차곡차곡 얹어 만들어요.',
        sentenceAdvanced: '태풍에 날아간 기왓장을 새로 얹느라 마을 어른들이 모두 모였어요.',
        liked: false,
      ),
    );

    expect(find.text(WordStrings.exampleInStory), findsOneWidget);
    expect(find.text(WordStrings.exampleInDaily), findsOneWidget);
    expect(find.text(WordStrings.exampleAdvanced), findsOneWidget);
    expect(find.textContaining('한옥 지붕은'), findsOneWidget);
    expect(find.textContaining('태풍에 날아간'), findsOneWidget);
  });

  testWidgets('예문 3종 이전에 담긴 단어는 이야기 칸만 보여준다', (WidgetTester tester) async {
    await open(
      tester,
      const SavedWord(
        wordId: 'w-2',
        word: '장대',
        meaning: '길고 굵은 나무 막대기',
        sentence: '장대로 배나무의 배를 따려고 했어요.',
        liked: false,
      ),
    );

    expect(find.text(WordStrings.exampleInStory), findsOneWidget);
    expect(find.text(WordStrings.exampleInDaily), findsNothing);
    expect(find.text(WordStrings.exampleAdvanced), findsNothing);
  });
}
