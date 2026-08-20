import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/screen_metrics.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/presentation/widgets/free_talk_friends_card.dart';
import '../../support/kid_text.dart';

/// 이야기 상세의 친구들 카드.
///
/// 이 카드가 하는 일은 둘입니다 — **누가 있는지 보여 주고**, 누른 친구를
/// 그대로 넘긴다. 얼굴 그림 자체는 번들 매니페스트가 없으면 로고 마크로
/// 떨어지므로(테스트 번들에는 에셋이 없습니다) 여기서 확인하지 않습니다.
void main() {
  const List<FreeTalkCharacter> friends = <FreeTalkCharacter>[
    FreeTalkCharacter(
      characterId: 'c1',
      name: '며느리',
      characterKey: 'daughter_in_law',
    ),
    FreeTalkCharacter(
      characterId: 'c2',
      name: '시아버지',
      characterKey: 'father_in_law',
    ),
    FreeTalkCharacter(
      characterId: 'c3',
      name: '마을 이장',
      characterKey: 'village_chief',
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required void Function(FreeTalkCharacter) onTap,
    List<FreeTalkCharacter> characters = friends,
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FreeTalkFriendsCard(
              characters: characters,
              metrics: ScreenMetrics.of(size.width),
              onTapCharacter: onTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('친구 셋이 한 화면에 다 보인다', (WidgetTester tester) async {
    await pump(tester, onTap: (_) {});

    // 버튼 한 줄이었을 때는 "친구가 셋"이라는 사실 자체가 화면에 없었습니다.
    expect(find.text(FreeTalkStrings.friendsIntro), findsOneWidget);
    expect(find.text(FreeTalkStrings.friendsHint), findsOneWidget);
    expect(findKidText('며느리'), findsOneWidget);
    expect(findKidText('시아버지'), findsOneWidget);
    expect(findKidText('마을 이장'), findsOneWidget);
  });

  testWidgets('누른 친구를 그대로 넘긴다', (WidgetTester tester) async {
    FreeTalkCharacter? tapped;
    await pump(tester, onTap: (FreeTalkCharacter c) => tapped = c);

    await tester.tap(findKidText('시아버지'));
    await tester.pumpAndSettle();

    // 인물 고르기 화면을 한 번 더 거치지 않습니다 — 얼굴을 누른 것이
    // 곧 고른 것입니다.
    expect(tapped?.characterId, 'c2');
  });

  testWidgets('한 번도 안 건 친구에게는 날짜 줄을 안 그린다', (WidgetTester tester) async {
    await pump(
      tester,
      onTap: (_) {},
      characters: <FreeTalkCharacter>[
        friends.first,
        FreeTalkCharacter(
          characterId: 'c2',
          name: '시아버지',
          characterKey: 'father_in_law',
          lastTalkedAt: DateTime.now(),
        ),
      ],
    );

    // "없음"이라 적으면 안 한 것이 못 한 것처럼 보입니다.
    expect(find.text(FreeTalkStrings.lastTalked(0)), findsOneWidget);
  });

  testWidgets('폰 폭에서 셋이 한 줄에 선다', (WidgetTester tester) async {
    await pump(tester, onTap: (_) {}, size: const Size(390, 844));

    // 얼굴 셋이 나란한 것이 이 카드의 전부입니다. 하나가 다음 줄로
    // 떨어지면 "친구가 셋"이 한눈에 안 읽힙니다.
    final double first = tester.getCenter(findKidText('며느리')).dy;
    final double last = tester.getCenter(findKidText('마을 이장')).dy;
    expect(last, first);
    expect(tester.takeException(), isNull);
  });
}
