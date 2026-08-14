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

  Finder slot(int index) => find.byKey(ValueKey<String>('recap-slot-$index'));
  Finder trayCard(String id) => find.byKey(ValueKey<String>('recap-tray-$id'));

  /// 탭 대체 경로(트레이 카드 선택 → 자리 탭)로 카드를 채웁니다.
  Future<void> placeByTap(
    WidgetTester tester,
    String cardId,
    int slotIndex,
  ) async {
    await tester.tap(trayCard(cardId));
    await tester.pump();
    await tester.tap(slot(slotIndex));
    await tester.pump();
  }

  Future<void> arrangeCorrectly(WidgetTester tester) async {
    await placeByTap(tester, 'scene-1', 0);
    await placeByTap(tester, 'scene-2', 1);
    await placeByTap(tester, 'scene-3', 2);
    await placeByTap(tester, 'scene-4', 3);
  }

  Future<void> arrangeWrongly(WidgetTester tester) async {
    await placeByTap(tester, 'scene-3', 0);
    await placeByTap(tester, 'scene-1', 1);
    await placeByTap(tester, 'scene-4', 2);
    await placeByTap(tester, 'scene-2', 3);
  }

  testWidgets('빈 순서 자리 4개와 섞인 장면 카드 4장을 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    expect(find.text('장면을 이야기 순서대로 놓아 보세요'), findsOneWidget);
    for (int i = 0; i < 4; i++) {
      expect(slot(i), findsOneWidget);
    }
    for (final String id in <String>[
      'scene-1',
      'scene-2',
      'scene-3',
      'scene-4',
    ]) {
      expect(trayCard(id), findsOneWidget);
    }
    // 그림만 보고 맞추는 활동이라 카드 제목은 화면에 없어야 합니다.
    expect(find.text('며느리가 방귀를 참느라 시무룩하게 서 있어요'), findsNothing);
  });

  testWidgets('빈 자리가 남아 있으면 확인 버튼이 비활성이다', (WidgetTester tester) async {
    await pumpRecap(tester);
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '이 순서로 확인하기'),
    );
    expect(button().onPressed, isNull);

    await placeByTap(tester, 'scene-1', 0);
    expect(button().onPressed, isNull);

    await placeByTap(tester, 'scene-2', 1);
    await placeByTap(tester, 'scene-3', 2);
    await placeByTap(tester, 'scene-4', 3);
    expect(button().onPressed, isNotNull);
  });

  testWidgets('자리에 놓은 카드를 다시 누르면 트레이로 돌아온다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await placeByTap(tester, 'scene-1', 0);
    expect(trayCard('scene-1'), findsNothing);

    await tester.tap(slot(0));
    await tester.pump();
    expect(trayCard('scene-1'), findsOneWidget);
  });

  testWidgets('틀린 순서는 부드러운 재시도 안내를 준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await arrangeWrongly(tester);
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
    expect(find.text('참다'), findsOneWidget);
    expect(find.text('쫓겨나다'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참느라'), findsOneWidget);
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

  testWidgets('좁은 폭에서도 자리와 트레이가 모두 보인다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PlayRecapPage(sessionId: 'recap-compact')),
    );
    await tester.pump();
    for (int i = 0; i < 4; i++) {
      expect(slot(i), findsOneWidget);
    }
    // 좁은 폭에서 트레이는 가로 스크롤이라 앞쪽 카드만 먼저 만들어집니다.
    expect(trayCard('scene-2'), findsOneWidget);
    // 가로로 밀면 카드가 딸려 오지 않고 트레이가 스크롤됩니다.
    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(trayCard('scene-1'), findsOneWidget);
  });

  testWidgets('좁은 폭의 2단계도 세로로 쌓여 무너지지 않는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await arrangeCorrectly(tester);
    await tester.tap(find.text('이 순서로 확인하기'));
    await tester.pump(const Duration(milliseconds: 800));
    // 화면 전환 애니메이션이 끝나기 전에는 1단계가 아직 트리에 남아 있습니다.
    // 그 상태로 폭을 줄이면 지나간 화면이 넘치므로 먼저 전환을 끝냅니다.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    tester.view.physicalSize = const Size(700, 900);
    await tester.pump();
    expect(find.text('장면과 낱말을 보며 이야기를 들려주세요'), findsOneWidget);
    expect(find.text('참다'), findsOneWidget);
  });

  testWidgets('카드가 5장이면 자리도 5칸이 된다', (WidgetTester tester) async {
    const List<RecapSceneCard> fiveCards = <RecapSceneCard>[
      RecapSceneCard(id: 'a', title: '가', image: 'assets/images/recap/a.webp'),
      RecapSceneCard(id: 'b', title: '나', image: 'assets/images/recap/b.webp'),
      RecapSceneCard(id: 'c', title: '다', image: 'assets/images/recap/c.webp'),
      RecapSceneCard(id: 'd', title: '라', image: 'assets/images/recap/d.webp'),
      RecapSceneCard(id: 'e', title: '마', image: 'assets/images/recap/e.webp'),
    ];
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayRecapPage(
          sessionId: 'recap-five',
          sceneCards: fiveCards,
          keywords: <String>['하나', '둘', '셋', '넷', '다섯'],
        ),
      ),
    );
    await tester.pump();

    for (int i = 0; i < 5; i++) {
      expect(slot(i), findsOneWidget);
    }
    expect(slot(5), findsNothing);
    expect(find.byKey(const ValueKey<String>('recap-tray-e')), findsOneWidget);

    for (int i = 0; i < 5; i++) {
      await placeByTap(tester, <String>['a', 'b', 'c', 'd', 'e'][i], i);
    }
    await tester.tap(find.text('이 순서로 확인하기'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    // 다섯 번째 낱말도 잘리지 않고 그려집니다.
    expect(find.text('다섯'), findsOneWidget);
  });

  testWidgets('1280x720 장면 순서 UI 골든', (WidgetTester tester) async {
    await pumpRecap(tester);
    await expectLater(
      find.byType(PlayRecapPage),
      matchesGoldenFile('goldens/play_recap_arrange.png'),
    );
  });
}
