import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/core/widgets/story_thumbnail.dart';
import 'package:goodquestion/features/home/domain/entities/child_profile.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/in_progress_session.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/home/domain/usecases/get_home_summary_use_case.dart';
import 'package:goodquestion/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:goodquestion/features/home/presentation/views/home_view.dart';
import 'package:goodquestion/features/home/presentation/widgets/start_story_card.dart';
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

/// 히어로에 올라간 편에 **가로 전용 표지가 없는** 상태. 세로 2:3 으로 폴백합니다.
const HomeSummary _withoutWideCover = HomeSummary(
  child: ChildProfile(name: '하늘이'),
  inProgressSession: InProgressSession(
    sessionId: '2482',
    storyTitle: '해와 달이 된 오누이',
    lastCompletedScene: 2,
    totalScenes: 5,
  ),
  recommendedStories: <RecommendedStory>[],
  planet: PlanetSummary(stardustBalance: 7),
);

/// 이어하기는 없지만 추천 큐레이션은 있는 상태. 1순위가 히어로로 올라갑니다.
const HomeSummary _withoutSession = HomeSummary(
  child: ChildProfile(name: '하늘이'),
  recommendedStories: <RecommendedStory>[
    RecommendedStory(
      storyId: '22',
      title: '의좋은 형제',
      estimatedMinutes: 20,
      topicTag: '옛이야기',
    ),
    RecommendedStory(
      storyId: '21',
      title: '해와 달이 된 오누이',
      estimatedMinutes: 15,
      topicTag: '용기',
    ),
  ],
  planet: PlanetSummary(stardustBalance: 0),
);

/// 이어하기도 추천도 없는 상태. 마지막 안전망([StartStoryCard])만 남습니다.
const HomeSummary _empty = HomeSummary(
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
          create: (_) =>
              HomeViewModel(GetHomeSummaryUseCase(repository))..load(),
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

  testWidgets('진행 중 세션이 없으면 추천 1순위가 히어로로 올라간다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withoutSession));

    expect(find.text(HomeStrings.todayBadge), findsOneWidget);
    expect(find.text(HomeStrings.todayAction), findsOneWidget);
    expect(find.text(HomeStrings.resume), findsNothing);
    // 히어로가 추천을 대신하므로 로고마크 카드는 나오지 않습니다.
    expect(find.byType(StartStoryCard), findsNothing);
    expect(find.text(HomeStrings.startTitle), findsNothing);
    // 히어로에 올린 한 편은 아래 목록에서 빠집니다 — 같은 표지가 한 화면에
    // 두 번 나오면 아이는 서로 다른 이야기로 셉니다.
    expect(find.text('의좋은 형제'), findsOneWidget);
    expect(find.text('해와 달이 된 오누이'), findsOneWidget);
  });

  /// 이 화면이 한 번 반려된 이유가 **표지 잘림**이었습니다. 원칙은
  /// "표지는 자르지 않는다"이고, 책장이 그 원칙을 지키는 자리입니다.
  /// 여기가 2:3 에서 벗어나면 목록·상세와 같은 표지가 홈에서만 다르게
  /// 잘려 보입니다. (`docs/COVER_ART_GUIDE.md` 7장)
  testWidgets('홈 책장의 표지는 세로 2:3 그대로다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withSession));

    // 히어로 한 장 + 추천 한 편. 히어로가 첫 번째입니다(위젯 트리 순서).
    final Finder covers = find.byType(StoryThumbnail);
    expect(covers, findsNWidgets(2));

    final Rect shelf = tester.getRect(covers.at(1));
    expect(
      shelf.width / shelf.height,
      closeTo(StoryThumbnail.portrait, 0.01),
      reason: '책장 표지가 2:3 이 아니라 잘립니다',
    );
  });

  /// 히어로도 이제 **자르지 않습니다.**
  ///
  /// 예전에는 세로 2:3 표지를 카드 전폭 배경으로 깔면서 원본 세로의 9% 만
  /// 남기는 원칙의 예외였습니다. 그 자리 비율로 그린 가로 전용 표지(2.5:1)가
  /// 들어오면서 예외가 사라졌습니다 — 패널 비율 = 그림 비율이라
  /// [BoxFit.cover] 가 잘라낼 게 없습니다.
  ///
  /// 이 테스트가 깨졌다면 히어로가 다시 그림을 자르고 있다는 뜻입니다.
  /// `docs/COVER_ART_GUIDE.md` 7장을 함께 보세요.
  testWidgets('가로 표지가 있으면 히어로 패널이 2.5:1 이다', (WidgetTester tester) async {
    // `방귀 뀌는 며느리` 는 가로 표지가 있는 두 편 중 하나입니다.
    expect(
      StoryThumbnail.localWideCoverAssetFor('방귀 뀌는 며느리'),
      isNotNull,
      reason: '이 테스트는 가로 표지가 있는 편을 전제로 합니다',
    );
    await pumpHome(tester, _StubRepository(summary: _withSession));

    final Rect hero = tester.getRect(find.byType(StoryThumbnail).first);
    expect(
      hero.width / hero.height,
      closeTo(StoryThumbnail.wideCover, 0.01),
      reason: '히어로 패널이 2.5:1 이 아니면 가로 표지가 잘립니다',
    );
  });

  /// 일곱 편 중 다섯 편은 아직 가로 표지가 없습니다. 그때는 **세로 2:3 을
  /// 옆에 세웁니다** — 어느 쪽이든 잘리지 않는다는 게 요점입니다.
  testWidgets('가로 표지가 없으면 히어로가 세로 2:3 으로 폴백한다', (
    WidgetTester tester,
  ) async {
    expect(
      StoryThumbnail.localWideCoverAssetFor('해와 달이 된 오누이'),
      isNull,
      reason: '이 편에 가로 표지를 추가했다면 이 테스트의 제목을 바꾸세요',
    );
    await pumpHome(tester, _StubRepository(summary: _withoutWideCover));

    final Rect hero = tester.getRect(find.byType(StoryThumbnail).first);
    expect(
      hero.width / hero.height,
      closeTo(StoryThumbnail.portrait, 0.01),
      reason: '폴백 히어로가 2:3 이 아니면 세로 표지가 잘립니다',
    );
  });

  testWidgets('추천까지 비면 새 이야기 카드로 폴백한다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _empty));

    expect(find.byType(StartStoryCard), findsOneWidget);
    expect(find.text(HomeStrings.startTitle), findsOneWidget);
    expect(find.text(HomeStrings.todayAction), findsNothing);
    expect(find.text(HomeStrings.resume), findsNothing);
  });

  testWidgets('상단 바·추천·행성·하단 내비가 함께 보인다', (WidgetTester tester) async {
    await pumpHome(tester, _StubRepository(summary: _withSession));

    expect(find.text('하늘이'), findsOneWidget);
    // 섹션 제목은 키워드만 색을 입히려고 RichText 로 그립니다.
    expect(
      find.text(HomeStrings.recommendedTitle, findRichText: true),
      findsOneWidget,
    );
    expect(find.text('해와 달이 된 오누이'), findsOneWidget);
    expect(find.text(HomeStrings.planetTitle), findsOneWidget);
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
