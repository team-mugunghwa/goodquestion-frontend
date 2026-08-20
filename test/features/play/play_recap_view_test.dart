import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/kid_button.dart';
import 'package:goodquestion/features/play/presentation/views/play_recap_view.dart';

/// 5장. **4를 가정한 레이아웃을 잡아내려고** 기본값과 개수를 다르게 둡니다.
const List<RecapSceneCard> fiveCards = <RecapSceneCard>[
  RecapSceneCard(id: 'a', title: '가', image: 'assets/images/recap/a.webp'),
  RecapSceneCard(id: 'b', title: '나', image: 'assets/images/recap/b.webp'),
  RecapSceneCard(id: 'c', title: '다', image: 'assets/images/recap/c.webp'),
  RecapSceneCard(id: 'd', title: '라', image: 'assets/images/recap/d.webp'),
  RecapSceneCard(id: 'e', title: '마', image: 'assets/images/recap/e.webp'),
];

/// 장면(5)보다 **많은** 낱말. 남는 낱말이 조용히 사라지지 않는지 봅니다.
const List<String> sixKeywords = <String>['하나', '둘', '셋', '넷', '다섯', '여섯'];

/// 장면(5)보다 **적은** 낱말. 남는 장면이 낱말 없이 그려지는지 봅니다.
const List<String> twoKeywords = <String>['하나', '둘'];

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
    String? storyId,
    String? lastCharacterName,
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
            storyId: storyId,
            lastCharacterName: lastCharacterName,
            sceneCards: cards ?? _defaults.sceneCards,
            keywords: keywords ?? _defaults.keywords,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 2단계의 장면 카드. **낱말까지 합친 한 덩어리 라벨**로 찾습니다 —
  /// 낱말이 따로 떨어져 나가면 이 finder 부터 깨집니다.
  Finder sceneCard(int order, String title, String? keyword) =>
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                (keyword == null
                    ? RecapStrings.sceneOrder(order, title)
                    : RecapStrings.sceneOrderWithKeyword(
                        order,
                        title,
                        keyword,
                      )),
      );

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

  testWidgets('1단계에는 낱말이 한 개도 나오지 않는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    // 낱말은 곧 장면의 정답 단서입니다. 트레이든 자리든 1단계에 있으면
    // 글을 읽는 아이에게 순서가 그대로 새어 나갑니다.
    for (final String word in <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감']) {
      expect(find.text(word), findsNothing, reason: '1단계에 "$word" 가 새어 나왔습니다');
    }

    // 카드를 다 놓아 "확인" 직전까지 가도 마찬가지입니다.
    await placeInOrder(tester);
    for (final String word in <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감']) {
      expect(find.text(word), findsNothing);
    }
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
    expect(find.text('그림 아래 낱말을 넣어서 들려줄래?'), findsNothing);
  });

  // ── 2단계 ────────────────────────────────────────────────

  testWidgets('정답이면 낱말이 붙은 장면 카드와 말풍선이 나온다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    // 안내문이 낱말을 과제로 지목합니다.
    expect(find.text('그림 아래 낱말을 넣어서 들려줄래?'), findsOneWidget);
    expect(find.text('참다'), findsOneWidget);
    expect(find.text('쫓겨나다'), findsOneWidget);
    // 아직 말하기 전이라 받아쓰기는 빈 말풍선입니다.
    expect(find.text('여기에 네 이야기가 글자로 보여'), findsOneWidget);
    expect(find.text('말하기'), findsOneWidget);
  });

  testWidgets('낱말은 장면 카드 안에, 정답 순서대로, 그림 아래에 붙는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    const List<String> words = <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감'];
    for (int i = 0; i < words.length; i++) {
      // ① 낱말이 i 번째 장면 카드의 **자식**입니다. 별도의 칩 줄이 아닙니다.
      //    (장면과 낱말이 한 덩어리로 읽히는지도 여기서 함께 봅니다)
      final Finder scene = sceneCard(
        i + 1,
        _defaults.sceneCards[i].title,
        words[i],
      );
      expect(
        scene,
        findsOneWidget,
        reason: '${i + 1}번째 장면에 ${words[i]} 가 없습니다',
      );
      expect(
        find.descendant(of: scene, matching: find.text(words[i])),
        findsOneWidget,
      );

      // ② 그림을 가리지 않습니다 — 낱말 띠가 그림 **아래**에 있습니다.
      final Rect image = tester.getRect(
        find.descendant(of: scene, matching: find.byType(Image)).first,
      );
      final Rect band = tester.getRect(
        find.descendant(of: scene, matching: find.text(words[i])),
      );
      expect(band.top, greaterThanOrEqualTo(image.bottom));
    }
  });

  testWidgets('받아쓰기 띠는 말하기 시작 이후로 계속 남는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    // ① 말하기 전 — 다음 버튼이 아직 없습니다. (기본 카드 4장 - 첫 장면은
    //    마지막이 아니니 다 말해도 "다 했어"가 아니라 "다음"입니다)
    expect(
      find.widgetWithText(KidPrimaryButton, RecapStrings.next),
      findsNothing,
    );
    expect(find.textContaining('며느리가 방귀를 참다가'), findsNothing);

    // ② 말하는 중.
    await tester.tap(find.text('말하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('멈추기'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, RecapStrings.next).onPressed, isNotNull);

    // ③ 곧바로 멈춰도 띠가 접히거나 다음 버튼이 죽지 않습니다.
    await tester.tap(find.text('멈추기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('말하기'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, RecapStrings.next).onPressed, isNotNull);
  });

  // ── 후속 자유 대화 진입점 ──────────────────────────────

  /// 순서 맞추기 → 다시 말하기(장면마다 한 번씩 말하기) → 완료까지 밀어 줍니다.
  Future<void> goToCompleted(WidgetTester tester, {int sceneCount = 4}) async {
    await goToRetell(tester);
    for (int i = 0; i < sceneCount; i++) {
      await tester.tap(find.text('말하기'));
      await tester.pump();
      final bool isLast = i == sceneCount - 1;
      await tester.tap(
        find.text(isLast ? RecapStrings.finish : RecapStrings.next),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('발화 완료 후 저장 완료 화면을 보여준다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToCompleted(tester);
    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  testWidgets('완료 화면에 "○○와 더 이야기하기" 진입점이 뜬다', (WidgetTester tester) async {
    await pumpRecap(tester, storyId: 'story-1', lastCharacterName: '시아버지');
    await goToCompleted(tester);

    // '지' 는 받침이 없어 '와' 입니다. (받침이 있으면 '과')
    expect(find.text('시아버지와 더 이야기하기'), findsOneWidget);
    // 마치기도 함께 남습니다 - 오늘 그만하고 싶은 아이의 문입니다.
    expect(find.text(RecapStrings.completedAction), findsOneWidget);
  });

  testWidgets('인물 이름을 모르면 일반 문구로 부른다', (WidgetTester tester) async {
    await pumpRecap(tester, storyId: 'story-1');
    await goToCompleted(tester);

    expect(find.text('이야기 친구와 더 이야기하기'), findsOneWidget);
  });

  testWidgets('이야기를 모르면 진입점을 아예 그리지 않는다', (WidgetTester tester) async {
    // 눌러 놓고 빈 화면을 보여 주는 것이 더 나쁩니다.
    await pumpRecap(tester);
    await goToCompleted(tester);

    expect(find.textContaining('더 이야기하기'), findsNothing);
    expect(find.text(RecapStrings.completedAction), findsOneWidget);
  });

  // ── 개수 가변 ────────────────────────────────────────────

  testWidgets('카드가 5장이면 자리도 5칸이고 장면마다 낱말이 붙는다', (WidgetTester tester) async {
    await pumpRecap(
      tester,
      cards: fiveCards,
      keywords: const <String>['하나', '둘', '셋', '넷', '다섯'],
    );
    for (int i = 0; i < 5; i++) {
      expect(slot(i), findsOneWidget);
    }
    expect(slot(5), findsNothing);
    expect(trayCard('e'), findsOneWidget);

    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    const List<String> titles = <String>['가', '나', '다', '라', '마'];
    const List<String> words = <String>['하나', '둘', '셋', '넷', '다섯'];
    for (int i = 0; i < 5; i++) {
      expect(sceneCard(i + 1, titles[i], words[i]), findsOneWidget);
    }
  });

  testWidgets('낱말이 장면보다 적으면 남는 장면은 낱말 없이 그린다', (WidgetTester tester) async {
    await pumpRecap(tester, cards: fiveCards, keywords: twoKeywords);
    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    expect(tester.takeException(), isNull);

    // 앞의 두 장면에만 낱말이 붙습니다.
    expect(sceneCard(1, '가', '하나'), findsOneWidget);
    expect(sceneCard(2, '나', '둘'), findsOneWidget);
    // 남는 장면은 낱말 없는 라벨이고, 카드 높이는 그대로입니다(줄이 들쭉날쭉하지 않음).
    for (int i = 2; i < 5; i++) {
      expect(
        sceneCard(i + 1, <String>['가', '나', '다', '라', '마'][i], null),
        findsOneWidget,
      );
    }
    expect(
      tester.getSize(sceneCard(1, '가', '하나')).height,
      tester.getSize(sceneCard(5, '마', null)).height,
    );
  });

  testWidgets('낱말이 장면보다 많으면 남는 낱말이 마지막 장면에 붙는다', (WidgetTester tester) async {
    await pumpRecap(tester, cards: fiveCards, keywords: sixKeywords);
    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    expect(tester.takeException(), isNull);

    // 조용히 버리지 않습니다 — 화면에도, 스크린리더에도 남습니다.
    expect(find.text('다섯 · 여섯'), findsOneWidget);
    expect(sceneCard(5, '마', '다섯 · 여섯'), findsOneWidget);
    // 그래도 줄 높이는 그대로입니다 — 띠는 한 줄로 고정입니다.
    expect(
      tester.getSize(sceneCard(1, '가', '하나')).height,
      tester.getSize(sceneCard(5, '마', '다섯 · 여섯')).height,
    );
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

  // ── 세로 예산 ────────────────────────────────────────────

  testWidgets('1280x720 — 2단계가 스크롤 없이 닫히고 그림이 하한 위에 있다', (
    WidgetTester tester,
  ) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    // 본문 스크롤뷰(장면 줄의 가로 ListView 보다 위에 있습니다).
    final ScrollableState body = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(body.position.maxScrollExtent, 0, reason: '2단계에 세로 스크롤이 생겼습니다');

    // 낱말 칩 줄(31.4+16)을 없애고 카드 테(43.4)로 바꾼 순증감은 -12 입니다.
    // 그림이 전보다 작아졌다면 예산 계산이 틀린 것입니다. (이전 139.4 → 149.6)
    final double image = tester
        .getSize(
          find
              .descendant(
                of: sceneCard(1, _defaults.sceneCards[0].title, '참다'),
                matching: find.byType(Image),
              )
              .first,
        )
        .height;
    expect(image, greaterThanOrEqualTo(139.4));
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
    expect(find.text('그림 아래 낱말을 넣어서 들려줄래?'), findsOneWidget);
    // 글자가 커지면 낱말 띠도 함께 커집니다. 띠 높이를 상수로 박아 두면
    // 여기서 카드가 넘칩니다.
    expect(find.text('하나'), findsOneWidget);
  });

  // ── 골든 ─────────────────────────────────────────────────

  testWidgets('1280x720 장면 순서 UI 골든', (WidgetTester tester) async {
    await pumpRecap(tester);
    await expectLater(
      find.byType(PlayRecapPage),
      matchesGoldenFile('goldens/play_recap_arrange.png'),
    );
  });

  /// 낱말이 장면 카드 안에 붙은 배치를 통째로 묶어 둡니다. 낱말이 다시
  /// 별도의 줄로 떨어져 나가거나 그림 위로 올라오면 여기서 걸립니다.
  testWidgets('1280x720 다시 말하기 UI 골든', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    await expectLater(
      find.byType(PlayRecapPage),
      matchesGoldenFile('goldens/play_recap_retell.png'),
    );
  });
}
