import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_spacing.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/kid_button.dart';
import 'package:goodquestion/core/widgets/kid_speech_bubble.dart';
import 'package:goodquestion/core/widgets/press_scale.dart';
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

  /// 2단계 채팅 로그에서 **지금 말할 장면 그림**. 제목은 화면에 그리지 않고
  /// 스크린리더 라벨로만 가므로, 그 라벨로 찾습니다.
  Finder sceneImage(int order, String title) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics &&
        widget.properties.label == RecapStrings.sceneOrder(order, title),
  );

  /// 낱말 칩. **체크 상태가 라벨에 들어 있습니다** — 켜짐과 꺼짐을 다른
  /// finder 로 찾아야 "안 쓴 낱말에 체크가 켜졌다"를 잡을 수 있습니다.
  Finder keywordChip(String word, {required bool used}) =>
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                (used
                    ? RecapStrings.keywordUsed(word)
                    : RecapStrings.keywordUnused(word)),
      );

  /// 체크 상태를 가리지 않는 낱말 칩. "이 장면에 이 낱말이 있는가"만 봅니다.
  Finder anyKeywordChip(String word) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics &&
        (widget.properties.label == RecapStrings.keywordUsed(word) ||
            widget.properties.label == RecapStrings.keywordUnused(word)),
  );

  /// 아이 발화 말풍선. 오른쪽·아이 면 색으로 그려집니다.
  Finder answerBubble() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is KidSpeechBubble && widget.speaker == KidSpeaker.child,
  );

  /// 마이크 버튼 전체(지름 120). 라벨 글자가 아니라 누르는 원을 잽니다.
  /// 듣는 중에는 라벨이 "멈추기"로 바뀌므로 둘 다 받습니다.
  Finder micButton() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is PressScale &&
        (widget.semanticLabel == RecapStrings.speak ||
            widget.semanticLabel == RecapStrings.stopSpeaking),
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

  /// 지금 장면을 말하고 다음 장면으로 넘어갑니다. (데모 모드는 마이크를
  /// 누르는 순간 고정 문장이 채워집니다)
  Future<void> speakAndNext(WidgetTester tester) async {
    await tester.tap(find.text(RecapStrings.speak));
    await tester.pump();
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('정답이면 첫 장면 질문과 그림·낱말 칩이 채팅으로 나온다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    // 안내문이 낱말을 과제로 지목합니다.
    expect(find.text('그림 아래 낱말을 넣어서 들려줄래?'), findsOneWidget);
    // 캐릭터가 첫 장면을 묻습니다. 장면 설명(정답)은 묻지 않습니다.
    expect(find.text(RecapStrings.sceneQuestion(1)), findsOneWidget);
    expect(find.text(_defaults.sceneCards[0].title), findsNothing);
    // 지금 말할 장면 그림 한 장과 그 장면 낱말만 있습니다.
    expect(sceneImage(1, _defaults.sceneCards[0].title), findsOneWidget);
    expect(sceneImage(2, _defaults.sceneCards[1].title), findsNothing);
    // 말하기 전이라 체크는 꺼져 있습니다 - 이건 "이 말을 써 보자"는 안내입니다.
    expect(keywordChip('참다', used: false), findsOneWidget);
    expect(keywordChip('참다', used: true), findsNothing);
    // 아직 아이 말풍선은 없습니다.
    expect(answerBubble(), findsNothing);
    expect(find.text('말하기'), findsOneWidget);
  });

  testWidgets('낱말은 지금 말할 장면 것만, 그 장면 그림 아래에 붙는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    const List<String> words = <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감'];
    for (int i = 0; i < words.length; i++) {
      final Finder scene = sceneImage(i + 1, _defaults.sceneCards[i].title);
      expect(scene, findsOneWidget, reason: '${i + 1}번째 장면 그림이 없습니다');

      // ① 지금 장면의 낱말만 화면에 있습니다. 다음 장면 낱말이 미리 보이면
      //    아직 묻지도 않은 그림의 단서가 새어 나갑니다.
      expect(
        anyKeywordChip(words[i]),
        findsOneWidget,
        reason: '${i + 1}번째 장면에 ${words[i]} 가 없습니다',
      );
      for (int j = 0; j < words.length; j++) {
        if (j == i) continue;
        expect(
          anyKeywordChip(words[j]),
          findsNothing,
          reason: '${i + 1}번째 장면에 ${j + 1}번째 낱말이 보입니다',
        );
      }

      // ② 그림을 가리지 않습니다 — 낱말 칩이 그림 **아래**에 있습니다.
      final Rect image = tester.getRect(
        find.descendant(of: scene, matching: find.byType(Image)).first,
      );
      final Rect chip = tester.getRect(find.text(words[i]));
      expect(chip.top, greaterThanOrEqualTo(image.bottom));

      if (i < words.length - 1) await speakAndNext(tester);
    }
  });

  testWidgets('아이 말풍선은 말한 뒤에 붙고 로그에 그대로 남는다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    // ① 말하기 전 — 아이 말풍선도 다음 버튼도 아직 없습니다. (기본 카드
    //    4장 - 첫 장면은 마지막이 아니니 다 말해도 "다 했어"가 아니라 "다음")
    expect(answerBubble(), findsNothing);
    expect(
      find.widgetWithText(KidPrimaryButton, RecapStrings.next),
      findsNothing,
    );
    expect(find.textContaining('며느리가 방귀를 참다가'), findsNothing);

    // ② 말하는 중 — 오른쪽 아이 말풍선이 붙습니다.
    await tester.tap(find.text('말하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('멈추기'), findsOneWidget);
    expect(answerBubble(), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, RecapStrings.next).onPressed, isNotNull);

    // ③ 곧바로 멈춰도 말풍선이 사라지거나 다음 버튼이 죽지 않습니다.
    await tester.tap(find.text('멈추기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('말하기'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(buttonWith(tester, RecapStrings.next).onPressed, isNotNull);

    // ④ 다음 장면으로 넘어가도 지나간 질문과 답은 로그에 남습니다.
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(RecapStrings.sceneQuestion(1)), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(find.text(RecapStrings.sceneQuestion(2)), findsOneWidget);
    // 다만 **그림은 지금 장면 하나뿐**입니다.
    expect(sceneImage(1, _defaults.sceneCards[0].title), findsNothing);
    expect(sceneImage(2, _defaults.sceneCards[1].title), findsOneWidget);
  });

  testWidgets('새 말풍선이 붙으면 로그가 아래로 따라 내려간다', (WidgetTester tester) async {
    await pumpRecap(tester);
    await goToRetell(tester);
    final ScrollableState log = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(log.position.pixels, 0);

    await tester.tap(find.text(RecapStrings.speak));
    await tester.pump();
    await tester.pumpAndSettle();

    // 답변이 화면 밖에 남으면 아이는 자기가 한 말이 어디로 갔는지 모릅니다.
    //
    // 답변 목록은 화면 상태가 **제자리에서 고쳐 쓰는 같은 List** 라서,
    // `didUpdateWidget` 에서 `oldWidget.answers` 와 비교하면 이미 같은 값이고
    // 여기서 스크롤이 0에 머무릅니다.
    expect(log.position.pixels, greaterThan(0));
    expect(log.position.pixels, log.position.maxScrollExtent);
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
      expect(
        sceneImage(i + 1, titles[i]),
        findsOneWidget,
        reason: '${i + 1}번째 장면에서 그림이 안 바뀌었습니다',
      );
      expect(anyKeywordChip(words[i]), findsOneWidget);
      if (i < 4) await speakAndNext(tester);
    }
  });

  testWidgets('낱말이 장면보다 적으면 남는 장면은 낱말 없이 그린다', (WidgetTester tester) async {
    await pumpRecap(tester, cards: fiveCards, keywords: twoKeywords);
    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    expect(tester.takeException(), isNull);

    const List<String> titles = <String>['가', '나', '다', '라', '마'];
    // 앞의 두 장면에만 낱말이 붙습니다.
    expect(anyKeywordChip('하나'), findsOneWidget);
    await speakAndNext(tester);
    expect(anyKeywordChip('둘'), findsOneWidget);

    // 남는 장면은 칩 없이 그림만 그립니다. 빈 칩 자리를 남기면 그 장면만
    // 고장 난 것처럼 보입니다.
    for (int i = 2; i < 5; i++) {
      await speakAndNext(tester);
      expect(tester.takeException(), isNull);
      expect(sceneImage(i + 1, titles[i]), findsOneWidget);
      for (final String word in twoKeywords) {
        expect(
          anyKeywordChip(word),
          findsNothing,
          reason: '${i + 1}번째 장면에 남의 낱말이 붙었습니다',
        );
      }
    }
  });

  testWidgets('낱말이 장면보다 많으면 남는 낱말이 마지막 장면에 붙는다', (WidgetTester tester) async {
    await pumpRecap(tester, cards: fiveCards, keywords: sixKeywords);
    await goToRetell(tester, <String>['a', 'b', 'c', 'd', 'e']);
    expect(tester.takeException(), isNull);

    for (int i = 0; i < 4; i++) {
      await speakAndNext(tester);
    }
    expect(tester.takeException(), isNull);

    // 조용히 버리지 않습니다 — 마지막 장면에 칩 두 개로 함께 붙습니다.
    expect(sceneImage(5, '마'), findsOneWidget);
    expect(anyKeywordChip('다섯'), findsOneWidget);
    expect(anyKeywordChip('여섯'), findsOneWidget);
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

  /// 채팅 로그는 **스크롤이 정상입니다.** 그래서 지키는 것이 둘로 바뀝니다 —
  /// 장면 그림이 하한 밑으로 내려가지 않을 것, 그리고 하단 마이크가 늘 화면
  /// 안에 있을 것.
  testWidgets('1280x720 — 장면 그림이 하한 위에 있고 마이크가 화면 안에 있다', (
    WidgetTester tester,
  ) async {
    await pumpRecap(tester);
    await goToRetell(tester);

    final double image = tester
        .getSize(
          find
              .descendant(
                of: sceneImage(1, _defaults.sceneCards[0].title),
                matching: find.byType(Image),
              )
              .first,
        )
        .height;
    // 그림 하한(140)보다 크고, 예전 한 줄 배치(149.6)보다도 큽니다.
    expect(image, greaterThanOrEqualTo(140));

    final Rect mic = tester.getRect(micButton());
    expect(mic.height, AppSizes.mic);
    expect(mic.top, greaterThanOrEqualTo(0));
    expect(mic.bottom, lessThanOrEqualTo(720));
  });

  testWidgets('폰 세로 — 말하기 전과 후에 마이크 자리가 같다', (WidgetTester tester) async {
    // 폰 세로는 마이크 아래에 다음 버튼을 쌓습니다. 버튼이 생겼다고 마이크가
    // 위로 밀리면, 아이 손이 기억한 자리가 어긋납니다.
    await pumpRecap(tester, size: const Size(390, 844));
    await goToRetell(tester);
    final Rect before = tester.getRect(micButton());

    await tester.tap(find.text(RecapStrings.speak));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(KidPrimaryButton, RecapStrings.next), findsOne);
    expect(tester.getRect(micButton()), before);
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
