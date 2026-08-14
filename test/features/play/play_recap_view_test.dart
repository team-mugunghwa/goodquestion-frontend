import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/kid_button.dart';
import 'package:goodquestion/features/play/presentation/views/play_recap_view.dart';

/// 5장·낱말 6개. **4를 가정한 레이아웃을 잡아내려고** 기본값과 개수를 다르게 둡니다.
const List<RecapSceneCard> fiveCards = <RecapSceneCard>[
  RecapSceneCard(id: 'a', title: '가', image: 'assets/images/recap/a.webp'),
  RecapSceneCard(id: 'b', title: '나', image: 'assets/images/recap/b.webp'),
  RecapSceneCard(id: 'c', title: '다', image: 'assets/images/recap/c.webp'),
  RecapSceneCard(id: 'd', title: '라', image: 'assets/images/recap/d.webp'),
  RecapSceneCard(id: 'e', title: '마', image: 'assets/images/recap/e.webp'),
];

const List<String> sixKeywords = <String>['하나', '둘', '셋', '넷', '다섯', '여섯'];

/// 화면의 기본 더미. 위젯이 들고 있는 값을 그대로 씁니다.
const PlayRecapPage _defaults = PlayRecapPage(sessionId: '_');

void main() {
  /// 실제 앱(`lib/app.dart`·`lib/main_recap_preview.dart`)과 **같은 테마**로 띄웁니다.
  /// 테마가 다르면 상속되는 글자 크기가 달라져서, 화면에서 나는 오버플로가
  /// 테스트에서만 안 납니다.
  Future<void> pumpRecap(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
    List<RecapSceneCard>? cards,
    List<String>? keywords,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: PlayRecapPage(
            sessionId: 'recap-test',
            sceneCards: cards ?? _defaults.sceneCards,
            keywords: keywords ?? _defaults.keywords,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder slot(int index) => find.byKey(ValueKey<String>('recap-slot-$index'));
  Finder trayCard(String id) => find.byKey(ValueKey<String>('recap-tray-$id'));
  Finder tray() => find.byKey(const ValueKey<String>('recap-tray'));

  KidPrimaryButton buttonWith(WidgetTester tester, String label) => tester
      .widget<KidPrimaryButton>(find.widgetWithText(KidPrimaryButton, label));

  /// 세로가 짧은 화면(폰 가로 등)에서는 본문이 스크롤됩니다.
  /// 화면 밖에 있는 것을 그냥 누르면 탭이 엉뚱한 데로 갑니다.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  /// 탭 대체 경로(트레이 카드 선택 → 자리 탭)로 카드를 채웁니다.
  Future<void> placeByTap(
    WidgetTester tester,
    String cardId,
    int slotIndex,
  ) async {
    await reveal(tester, trayCard(cardId));
    await tester.tap(trayCard(cardId));
    await tester.pump();
    await reveal(tester, slot(slotIndex));
    await tester.tap(slot(slotIndex));
    await tester.pump();
  }

  Future<void> placeInOrder(
    WidgetTester tester, [
    List<String> ids = const <String>[
      'scene-1',
      'scene-2',
      'scene-3',
      'scene-4',
    ],
  ]) async {
    // 좁은 화면의 트레이는 가로 스크롤이라 **보이는 카드만 만들어집니다.**
    // 늘 지금 트레이에 있는 카드를 골라 제자리에 놓습니다.
    final List<String> remaining = List<String>.of(ids);
    while (remaining.isNotEmpty) {
      final String next = remaining.firstWhere(
        (String id) => trayCard(id).evaluate().isNotEmpty,
        orElse: () => remaining.first,
      );
      await placeByTap(tester, next, ids.indexOf(next));
      remaining.remove(next);
    }
  }

  /// 정답 순서로 놓고 1단계를 통과해 2단계까지 갑니다. 전환 애니메이션도 끝냅니다.
  Future<void> goToRetell(
    WidgetTester tester, [
    List<String> ids = const <String>[
      'scene-1',
      'scene-2',
      'scene-3',
      'scene-4',
    ],
  ]) async {
    await placeInOrder(tester, ids);
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  // ── 1단계 ────────────────────────────────────────────────

  testWidgets('빈 순서 자리 4개와 섞인 장면 카드 4장을 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    expect(find.text('아래 그림을 이야기 순서대로 놓아 볼래?'), findsOneWidget);
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
    expect(buttonWith(tester, '확인').onPressed, isNull);

    await placeByTap(tester, 'scene-1', 0);
    expect(buttonWith(tester, '확인').onPressed, isNull);

    await placeByTap(tester, 'scene-2', 1);
    await placeByTap(tester, 'scene-3', 2);
    await placeByTap(tester, 'scene-4', 3);
    expect(buttonWith(tester, '확인').onPressed, isNotNull);
  });

  testWidgets('자리에 놓은 카드를 다시 누르면 트레이로 돌아온다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await placeByTap(tester, 'scene-1', 0);
    expect(trayCard('scene-1'), findsNothing);

    await tester.tap(slot(0));
    await tester.pump();
    expect(trayCard('scene-1'), findsOneWidget);
  });

  testWidgets('트레이가 비면 트레이 영역이 접힌다', (WidgetTester tester) async {
    await pumpRecap(tester);
    expect(tray(), findsOneWidget);
    final double before = tester.getSize(slot(0)).height;

    await placeInOrder(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // 빈 흰 띠를 남기지 않습니다.
    expect(tray(), findsNothing);
    // 접힌 만큼 장면 그림이 커집니다(폭이 먼저 걸리는 화면에서는 최소 유지).
    expect(tester.getSize(slot(0)).height, greaterThanOrEqualTo(before));

    // 되돌리면 다시 펼쳐집니다.
    await tester.tap(slot(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tray(), findsOneWidget);
  });

  testWidgets('틀린 순서는 캐릭터가 부드럽게 다시 권한다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await placeInOrder(tester, <String>[
      'scene-3',
      'scene-1',
      'scene-4',
      'scene-2',
    ]);
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('거의 다 왔어'), findsOneWidget);
    // 여전히 1단계입니다.
    expect(find.text('그림을 보면서 이야기를 들려줄래?'), findsNothing);
  });

  // ── 2단계 ────────────────────────────────────────────────

  testWidgets('정답이면 장면 줄·낱말·말풍선이 있는 2단계로 간다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    expect(find.text('그림을 보면서 이야기를 들려줄래?'), findsOneWidget);
    expect(find.text('참다'), findsOneWidget);
    expect(find.text('쫓겨나다'), findsOneWidget);
    // 아직 말하기 전이라 받아쓰기는 빈 말풍선입니다.
    expect(find.text('여기에 네 이야기가 글자로 보여'), findsOneWidget);
    expect(find.text('말하기'), findsOneWidget);
  });

  testWidgets('받아쓰기 띠는 말하기 시작 이후로 계속 남는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    // ① 말하기 전 — 완료 버튼이 아직 없습니다.
    expect(find.widgetWithText(KidPrimaryButton, '다 했어'), findsNothing);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsNothing);

    // ② 말하는 중.
    await tester.tap(find.text('말하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('멈추기'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, '다 했어').onPressed, isNotNull);

    // ③ 곧바로 멈춰도 띠가 접히거나 완료 버튼이 죽지 않습니다.
    await tester.tap(find.text('멈추기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('말하기'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, '다 했어').onPressed, isNotNull);
  });

  testWidgets('발화 완료 후 저장 완료 화면을 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    await tester.tap(find.text('말하기'));
    await tester.pump();
    await tester.tap(find.text('다 했어'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  // ── 개수 가변 ────────────────────────────────────────────

  testWidgets('카드가 5장이면 자리도 5칸이고 낱말 6개가 다 그려진다', (WidgetTester tester) async {
    await pumpRecap(tester, cards: fiveCards, keywords: sixKeywords);
    for (int i = 0; i < 5; i++) {
      expect(slot(i), findsOneWidget);
    }
    expect(slot(5), findsNothing);
    expect(trayCard('e'), findsOneWidget);

    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    for (final String word in sixKeywords) {
      expect(find.text(word), findsOneWidget);
    }
  });

  testWidgets('좁은 폭에서는 트레이가 가로로 스크롤된다', (WidgetTester tester) async {
    await pumpRecap(tester, size: const Size(360, 780));
    for (int i = 0; i < 4; i++) {
      expect(slot(i), findsOneWidget);
    }
    // 앞쪽 카드만 먼저 만들어집니다.
    expect(trayCard('scene-2'), findsOneWidget);
    // 가로로 밀면 카드가 딸려 오지 않고 트레이가 스크롤됩니다.
    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(trayCard('scene-1'), findsOneWidget);
  });

  // ── 오버플로 0 ───────────────────────────────────────────

  const Map<String, Size> viewports = <String, Size>{
    '태블릿 가로 1280x800': Size(1280, 800),
    '아이패드 1024x768': Size(1024, 768),
    '폰 가로 844x390': Size(844, 390),
    '폰 세로 360x780': Size(360, 780),
  };

  for (final MapEntry<String, Size> entry in viewports.entries) {
    testWidgets('${entry.key} — 카드 5장·낱말 6개로 두 단계 모두 넘치지 않는다', (
      WidgetTester tester,
    ) async {
      await pumpRecap(
        tester,
        size: entry.value,
        cards: fiveCards,
        keywords: sixKeywords,
      );
      expect(tester.takeException(), isNull);

      await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('말하기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('글자 확대 1.3배에서도 두 단계가 깨지지 않는다', (WidgetTester tester) async {
    await pumpRecap(
      tester,
      size: const Size(1280, 800),
      cards: fiveCards,
      keywords: sixKeywords,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    expect(tester.takeException(), isNull);
    expect(find.text('그림을 보면서 이야기를 들려줄래?'), findsOneWidget);
  });

  // ── 골든 ─────────────────────────────────────────────────

  testWidgets('1280x720 장면 순서 UI 골든', (WidgetTester tester) async {
    await pumpRecap(tester);
    await expectLater(
      find.byType(PlayRecapPage),
      matchesGoldenFile('goldens/play_recap_arrange.png'),
    );
  });
}
