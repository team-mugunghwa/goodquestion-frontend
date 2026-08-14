import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';

void main() {
  Future<void> pumpPlay(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PlayPage(
          sessionId: 'preview-session',
          characterName: '토리',
          question: '친구가 속상해할 때는 어떻게 하면 좋을까?',
        ),
      ),
    );
  }

  testWidgets('좌측 캐릭터와 머리 우측의 한 문장 질문을 보여준다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.text('토리'), findsOneWidget);
    expect(find.text('친구가 속상해할 때는 어떻게 하면 좋을까?'), findsOneWidget);
    expect(find.text('토리이 말하고 있어요'), findsOneWidget);
    expect(find.text('질문이 끝나면 마이크가 자동으로 켜져요.'), findsOneWidget);
  });

  testWidgets('질문이 끝나면 자동으로 마이크가 켜진다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.bySemanticsLabel('마이크 준비 중'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
    expect(find.textContaining('잘 듣고 있어요'), findsOneWidget);
    expect(find.text('한 문장으로 천천히 말해 주세요'), findsOneWidget);
  });

  testWidgets('다시 듣기와 일시정지 동작이 명확하다', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.byTooltip('다시 듣기'));
    await tester.pump();
    expect(find.text('토리이 말하고 있어요'), findsOneWidget);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);

    await tester.tap(find.text('계속 듣기'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsNothing);
  });

  testWidgets('나가기는 실수 방지를 위해 확인한다', (WidgetTester tester) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('이야기를 나갈까요?'), findsOneWidget);
    expect(find.text('지금까지 들은 곳은 저장해 둘게요.'), findsOneWidget);
  });

  testWidgets('1280x720 범용 대화 템플릿 골든', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump();

    await expectLater(
      find.byType(PlayPage),
      matchesGoldenFile('goldens/play_dialogue_template.png'),
    );
  });
}
