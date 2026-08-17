import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/features/home/domain/entities/child_profile.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/in_progress_session.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/home/domain/usecases/get_home_summary_use_case.dart';
import 'package:goodquestion/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:goodquestion/features/home/presentation/views/home_view.dart';
import 'package:goodquestion/features/mypage/domain/entities/my_page_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
import 'package:goodquestion/features/mypage/domain/usecases/my_page_use_cases.dart';
import 'package:provider/provider.dart';

class _StubRepository implements HomeRepository {
  _StubRepository({this.summary, this.error});

  final HomeSummary? summary;
  final Object? error;

  @override
  Future<HomeSummary> getHomeSummary() async {
    if (error != null) throw error!;
    return summary!;
  }
}

const HomeSummary _withSession = HomeSummary(
  child: ChildProfile(name: '하늘이'),
  inProgressSession: InProgressSession(
    sessionId: '2481',
    storyTitle: '방귀 뀌는 며느리',
    lastCompletedScene: 3,
    totalScenes: 5,
  ),
  recommendedStories: <RecommendedStory>[
    RecommendedStory(
      storyId: '21',
      title: '해와 달이 된 오누이',
      estimatedMinutes: 15,
      topicTag: '용기',
    ),
  ],
  planet: PlanetSummary(stardustBalance: 7),
);

const HomeSummary _withoutSession = HomeSummary(
  child: ChildProfile(name: '하늘이'),
  recommendedStories: <RecommendedStory>[],
  planet: PlanetSummary(stardustBalance: 0),
);

void main() {
  /// 태블릿(주 타겟) 크기로 띄웁니다. 폰만 확인하고 넘어가지 않기 위해서입니다.
  Future<void> pumpHome(
    WidgetTester tester,
    HomeRepository repository, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            GetHomeSummaryUseCase(repository),
            const GetMyPageChildrenUseCase(_StubChildren()),
            const SelectMyPageChildUseCase(_StubChildren()),
          )..load(),
          child: const HomeView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진행 중 세션이 있으면 이어하기 카드가 뜬다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withSession));

    expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
    expect(find.text(HomeStrings.resume), findsOneWidget);
    expect(find.text(HomeStrings.sceneProgress(3)), findsOneWidget);
    // 진행 중일 때 "새 이야기 시작" 카드가 함께 뜨면 시선이 갈립니다.
    expect(find.text(HomeStrings.startTitle), findsNothing);
  });

  testWidgets('진행 중 세션이 없으면 새 이야기 카드로 바뀐다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withoutSession));

    expect(find.text(HomeStrings.startTitle), findsOneWidget);
    expect(find.text(HomeStrings.resume), findsNothing);
  });

  testWidgets('상단 바·추천·행성·하단 내비가 함께 보인다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withSession));

    expect(find.text(HomeStrings.greeting('하늘이')), findsOneWidget);
    // 섹션 제목은 키워드만 색을 입히려고 RichText 로 그립니다.
    expect(
      find.text(HomeStrings.recommendedTitle, findRichText: true),
      findsOneWidget,
    );
    expect(find.text('해와 달이 된 오누이'), findsOneWidget);
    expect(find.text(NavStrings.planet), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('실패해도 아이 화면에는 빨강 대신 다시 불러오기 버튼이 뜬다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(error: const NetworkFailure()));

    expect(find.text(AppStrings.retryKid), findsOneWidget);
    // 에러 중에도 다른 화면으로 나갈 수 있어야 합니다.
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('폰 폭에서도 레이아웃이 무너지지 않는다', (WidgetTester tester) async {
    await pumpHome(
      tester,
      _StubRepository(summary: _withSession),
      size: const Size(390, 844),
    );

    expect(find.text(HomeStrings.resume), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// 아이 목록·전환은 홈의 곁가지라 테스트용 고정 저장소를 씁니다.
class _StubChildren implements ChildProfileRepository {
  const _StubChildren();

  @override
  String? get selectedChildId => 'c1';

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<List<MyPageChild>> getChildren() async => const <MyPageChild>[
    MyPageChild(childId: 'c1', name: '하늘이', age: 8),
  ];

  @override
  Future<void> selectChild(String childId) async {}
}
