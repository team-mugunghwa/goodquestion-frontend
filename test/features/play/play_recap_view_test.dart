import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/presentation/views/play_recap_view.dart';

void main() {
  Future<void> pumpRecap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PlayRecapPage(sessionId: 'recap-test')),
    );
    await tester.pump();
  }

  Future<void> arrangeCorrectly(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('recap-card-scene-1')));
    await tester.pump();
    await tester.tap(find.byTooltip('왼쪽으로 옮기기'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('recap-card-scene-2')));
    await tester.pump();
    await tester.tap(find.byTooltip('왼쪽으로 옮기기'));
    await tester.tap(find.byTooltip('왼쪽으로 옮기기'));
    await tester.pump();
  }

  testWidgets('무작위 장면 카드와 순서 맞추기 안내를 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    expect(find.text('장면을 이야기 순서대로 놓아 보세요'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('이 순서로 확인하기'), findsOneWidget);
  });

  testWidgets('틀린 순서는 부드러운 재시도 안내를 준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await tester.tap(find.text('이 순서로 확인하기'));
    await tester.pump();
    expect(find.textContaining('거의 다 왔어요'), findsOneWidget);
  });

  testWidgets('정답이면 핵심 단어와 다시 말하기 화면으로 간다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await arrangeCorrectly(tester);
    await tester.tap(find.text('이 순서로 확인하기'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('장면과 낱말을 보며 이야기를 들려주세요'), findsOneWidget);
    expect(find.text('고민'), findsOneWidget);
    expect(find.text('솔직하게'), findsOneWidget);
    expect(find.textContaining('처음에는 주인공에게'), findsOneWidget);
  });

  testWidgets('발화 완료 후 저장 완료 화면을 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await arrangeCorrectly(tester);
    await tester.tap(find.text('이 순서로 확인하기'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.tap(find.text('이야기 다 했어요'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('이야기를 멋지게 다시 들려줬어요!'), findsOneWidget);
  });

  testWidgets('1280x720 장면 순서 UI 골든', (WidgetTester tester) async {
    await pumpRecap(tester);
    await expectLater(
      find.byType(PlayRecapPage),
      matchesGoldenFile('goldens/play_recap_arrange.png'),
    );
  });
}
