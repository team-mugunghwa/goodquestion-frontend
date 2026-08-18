import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/presentation/views/free_talk_characters_view.dart';

import 'fakes.dart';

const List<FreeTalkCharacter> _threeCharacters = <FreeTalkCharacter>[
  FreeTalkCharacter(
    characterId: 'c-1',
    name: '방귀쟁이 며느리',
    characterKey: 'daughter_in_law',
  ),
  FreeTalkCharacter(
    characterId: 'c-2',
    name: '시아버지',
    characterKey: 'father_in_law',
  ),
  FreeTalkCharacter(
    characterId: 'c-3',
    name: '마을 이장',
    characterKey: 'village_chief',
  ),
];

void main() {
  Future<void> pumpPick(
    WidgetTester tester, {
    required FakeFreeTalkRepository repository,
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FreeTalkCharactersPage(
          storyId: 'story-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('완주한 이야기의 인물을 카드로 늘어놓는다', (WidgetTester tester) async {
    await pumpPick(
      tester,
      repository: FakeFreeTalkRepository(charactersResult: _threeCharacters),
    );

    expect(find.text('누구랑 더 이야기해볼까?'), findsOneWidget);
    expect(find.text('방귀쟁이 며느리'), findsOneWidget);
    expect(find.text('시아버지'), findsOneWidget);
    expect(find.text('마을 이장'), findsOneWidget);
  });

  testWidgets('마지막 대화가 없으면 그 줄을 그리지 않는다', (WidgetTester tester) async {
    // "없음"이라고 적으면 안 한 것이 못 한 것처럼 보입니다.
    await pumpPick(
      tester,
      repository: FakeFreeTalkRepository(
        charactersResult: <FreeTalkCharacter>[
          FreeTalkCharacter(
            characterId: 'c-1',
            name: '며느리',
            characterKey: 'a',
            lastTalkedAt: DateTime.now(),
          ),
          const FreeTalkCharacter(
            characterId: 'c-2',
            name: '시아버지',
            characterKey: 'b',
          ),
        ],
      ),
    );

    expect(find.text('오늘 이야기했어'), findsOneWidget);
    expect(find.textContaining('이야기했어'), findsOneWidget);
  });

  testWidgets('완주 전이면 에러가 아니라 안내로 돌려세운다', (WidgetTester tester) async {
    await pumpPick(
      tester,
      repository: FakeFreeTalkRepository(
        charactersError: const ServerFailure(
          message: '완주하지 않은 이야기입니다.',
          code: 'STORY_NOT_COMPLETED',
        ),
      ),
    );

    expect(find.text('이야기를 끝까지 들으면 친구들이 기다리고 있을 거야!'), findsOneWidget);
    // 다시 눌러도 같은 답이 오므로 재시도 버튼을 주지 않습니다.
    expect(find.text('다시 해볼래'), findsNothing);
  });

  testWidgets('네트워크 실패는 다시 시도할 수 있다', (WidgetTester tester) async {
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository(
      charactersError: const NetworkFailure(),
    );
    await pumpPick(tester, repository: repository);

    expect(find.text('친구들을 부르지 못했어. 다시 해볼까?'), findsOneWidget);
    expect(repository.charactersCalls, 1);
  });

  testWidgets('인물이 없으면 빈 화면 대신 나갈 문을 준다', (WidgetTester tester) async {
    await pumpPick(tester, repository: FakeFreeTalkRepository());

    expect(find.text('지금은 이야기할 친구가 없어. 다른 이야기를 들어 볼까?'), findsOneWidget);
    expect(find.text('이야기 보기'), findsOneWidget);
  });

  testWidgets('카드를 누르면 그 인물의 대화 주소로 간다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.freeTalkOf('story-1'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.freeTalkPath,
          builder: (_, GoRouterState state) => FreeTalkCharactersPage(
            storyId: state.pathParameters[AppRoutes.storyIdParam]!,
            repository: FakeFreeTalkRepository(
              charactersResult: _threeCharacters,
            ),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: ':${AppRoutes.characterIdParam}',
              builder: (_, GoRouterState state) => Scaffold(
                body: Text(
                  '대화: ${state.pathParameters[AppRoutes.characterIdParam]}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('시아버지'));
    await tester.pumpAndSettle();

    expect(find.text('대화: c-2'), findsOneWidget);
  });
}
