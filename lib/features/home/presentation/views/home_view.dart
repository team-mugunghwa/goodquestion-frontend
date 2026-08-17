import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/cosmic_backdrop.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../mypage/domain/usecases/my_page_use_cases.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/entities/in_progress_session.dart';
import '../../domain/entities/recommended_story.dart';
import '../../domain/usecases/get_home_summary_use_case.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/continue_card.dart';
import '../widgets/home_sheets.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/recommended_stories_section.dart';
import '../widgets/start_story_card.dart';
import '../widgets/today_story_card.dart';

/// 홈 — 이어하기 · 추천 이야기 · 행성 위젯 · 하단 내비 허브.
///
/// ## 이 화면이 하는 한 가지 일
///
/// **아이의 다음 행동을 3초 안에 결정하게 만드는 것.** 진행 중 세션이 있으면
/// 이어하기를 화면에서 가장 크게 밀어 완주율(검증 지표 60%)을 지킵니다.
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 상단 바 — 아이 프로필 · 별가루 잔액 · 내 행성 입구 |
/// | 2 | 히어로 — 이어하기 / 오늘의 이야기 / (둘 다 없으면) 새 이야기 시작 |
/// | 3 | 추천 이야기 2~3개 (고정 큐레이션, 히어로에 쓴 편은 제외) |
/// | 4 | 하단 내비 (고정) |
///
/// 섹션2는 **표지 패널 + 흰 글자 면**으로 나뉜 카드입니다([HomeHeroCard]).
/// 세 상태가 같은 껍데기를 써서, 이어하던 이야기가 있든 없든 아이의 손이
/// 가는 자리가 바뀌지 않습니다.
///
/// 섹션3은 **세로 2:3 표지를 통째로 세운 책장**입니다. 두 섹션 다 표지를
/// 자르지 않습니다 — 히어로는 그 자리 비율로 그린 가로 전용 표지(2.5:1)를
/// 쓰고, 그 그림이 아직 없는 편은 세로 2:3 표지를 옆에 세웁니다.
/// (`docs/COVER_ART_GUIDE.md` 7장)
///
/// 바탕은 `AppCanvas.day`. 이 앱은 낮(홈·이야기)에서 시작해 밤(완료·행성)에서
/// 끝납니다. → `docs/DESIGN_SYSTEM.md`
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(
        getIt<GetHomeSummaryUseCase>(),
        getIt<GetMyPageChildrenUseCase>(),
        getIt<SelectMyPageChildUseCase>(),
      )..load(),
      child: const HomeView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeViewModel vm = context.watch<HomeViewModel>();
    final HomeSummary? summary = vm.summary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: Stack(
          children: <Widget>[
            // 다른 화면과 같은 하늘. 위쪽엔 반짝이는 별과 유성, 아래쪽엔
            // 화면 밖으로 반쯤 잠긴 달이 뜹니다.
            const CosmicBackdrop(
              seed: 5,
              planetCenterX: 0.5,
              bottomInset: AppSizes.bottomNav + AppSpacing.lg,
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final ScreenMetrics metrics = ScreenMetrics.of(
                    constraints.maxWidth,
                  );
                  return Column(
                    children: <Widget>[
                      HomeTopBar(
                        metrics: metrics,
                        child: summary?.child,
                        stardustBalance: summary?.planet.stardustBalance,
                        isLoading: summary == null && !vm.state.isError,
                        onProfileTap: () => _openChildSwitch(context, metrics),
                        onPlanetTap: () => context.go(AppRoutes.planet),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: respect(context, AppDurations.normal),
                          switchInCurve: AppCurves.standard,
                          switchOutCurve: AppCurves.exit,
                          // 기본 layoutBuilder 는 자식을 Stack 가운데에 느슨하게
                          // 놓습니다. 그러면 본문이 세로로 붕 떠서, 상단 바와
                          // 이어하기 카드 사이가 화면마다 다르게 벌어집니다.
                          layoutBuilder:
                              (Widget? current, List<Widget> previous) => Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previous,
                                  if (current != null) current,
                                ],
                              ),
                          child: _buildBody(context, vm, metrics),
                        ),
                      ),
                      // 로딩·에러 중에도 하단 내비는 즉시 보입니다. 아이가
                      // 갇힌 느낌을 받으면 안 됩니다.
                      const AppBottomNav(current: AppNavTab.home),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeViewModel vm,
    ScreenMetrics metrics,
  ) {
    final HomeSummary? summary = vm.summary;
    return switch (vm.state) {
      ViewState.error => AppKidErrorView(
        key: const ValueKey<String>('home-error'),
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: vm.load,
      ),
      ViewState.success when summary != null => _HomeContent(
        key: const ValueKey<String>('home-content'),
        summary: summary,
        metrics: metrics,
      ),
      _ => HomeSkeleton(
        key: const ValueKey<String>('home-skeleton'),
        metrics: metrics,
      ),
    };
  }

  Future<void> _openChildSwitch(
    BuildContext context,
    ScreenMetrics metrics,
  ) async {
    final HomeViewModel vm = context.read<HomeViewModel>();
    final String? childId = await showChildSwitchSheet(
      context,
      metrics: metrics,
      children: vm.children,
      current: vm.summary?.child,
    );
    // 고른 아이가 있으면 그 아이 기준으로 홈을 다시 받습니다.
    if (childId != null) await vm.selectChild(childId);
  }
}

/// 섹션2~3. 스크롤되는 본문입니다.
class _HomeContent extends StatelessWidget {
  const _HomeContent({super.key, required this.summary, required this.metrics});

  final HomeSummary summary;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final InProgressSession? session = summary.inProgressSession;
    final List<RecommendedStory> recommended = summary.recommendedStories;
    // 이어하기가 없으면 추천 1순위가 히어로로 올라갑니다. 그 한 편은 아래
    // 목록에서 빼서 같은 표지가 한 화면에 두 번 나오지 않게 합니다.
    // (이어하기가 있을 때는 빼지 않습니다 — 목록은 목록대로 온전해야 합니다)
    final RecommendedStory? todayStory =
        session == null && recommended.isNotEmpty ? recommended.first : null;
    final List<RecommendedStory> listed = todayStory == null
        ? recommended
        : recommended.sublist(1);

    // 본문에 실제로 주어진 세로(뷰포트 − 상단 바 − 하단 내비)를 재서 아래
    // 책장의 표지 폭을 정합니다. 표지를 자르지 않기로 하면 표지 폭이 곧 높이
    // (×1.5)라, 세로 예산을 모르면 "표지와 제목까지 첫 화면 안에"를 못 지킵니다.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            // 위쪽 여백만 md 입니다. 세로 표지를 자르지 않기로 하면서 본문이
            // 세로로 길어졌고, 상단 바가 이미 자기 여백을 갖고 있어 여기서
            // lg 까지 벌리면 그 8dp 가 책장의 라벨을 첫 화면 밖으로 밀어냅니다.
            padding: EdgeInsets.fromLTRB(
              metrics.screenPadding,
              AppSpacing.md,
              metrics.screenPadding,
              metrics.screenPadding,
            ),
            child: _column(
              context,
              session,
              todayStory,
              listed,
              RecommendedStoriesSection.coverWidthOf(
                context,
                metrics,
                constraints.maxWidth - metrics.screenPadding * 2,
                constraints.maxHeight,
              ),
            ),
          ),
    );
  }

  Widget _column(
    BuildContext context,
    InProgressSession? session,
    RecommendedStory? todayStory,
    List<RecommendedStory> listed,
    double coverWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (session != null)
          ContinueCard(
            session: session,
            metrics: metrics,
            onResume: () => _guarded(
              context,
              // 전체 장면 수는 홈만 알고 있습니다 - 재생 화면 진행바가
              // 쓰도록 함께 넘깁니다. → [AppRoutes.playOf]
              () => context.go(
                AppRoutes.playOf(
                  session.sessionId,
                  totalScenes: session.totalScenes,
                ),
              ),
            ),
          )
        else if (todayStory != null)
          TodayStoryCard(
            story: todayStory,
            metrics: metrics,
            // 추천 카드 탭과 같은 동작입니다 — 세션은 상세에서 시작합니다.
            onTap: () => _guarded(
              context,
              () => context.push(AppRoutes.storyDetailOf(todayStory.storyId)),
            ),
          )
        else
          // 추천 큐레이션까지 비었을 때의 마지막 안전망.
          StartStoryCard(
            metrics: metrics,
            onStart: () =>
                _guarded(context, () => context.go(AppRoutes.stories)),
          ),
        // 히어로와 추천 사이는 sectionGap(태블릿 64) 대신 lg 입니다.
        // 세로 표지를 자르지 않으면 책 한 권이 폭의 1.5배로 길어지는데, 그 사이를
        // 64로 벌리면 표지 밑 라벨이 첫 화면 밖으로 밀립니다.
        const SizedBox(height: AppSpacing.lg),
        RecommendedStoriesSection(
          stories: listed,
          metrics: metrics,
          coverWidth: coverWidth,
          // push 입니다 — 상세의 뒤로가기가 홈으로 돌아와야 합니다.
          onStoryTap: (RecommendedStory story) => _guarded(
            context,
            () => context.push(AppRoutes.storyDetailOf(story.storyId)),
          ),
          onMoreTap: () => context.go(AppRoutes.stories),
        ),
      ],
    );
  }

  /// 아이 프로필이 없으면 이야기로 못 들어갑니다. (PRD F-01)
  ///
  /// 라우터 `redirect` 로도 막을 예정이지만, 홈에서는 **막힌 이유를 아이 말로**
  /// 알려 주는 편이 낫습니다. 리다이렉트만 걸면 눌렀는데 아무 일도 안 일어난
  /// 것처럼 보입니다.
  void _guarded(BuildContext context, VoidCallback proceed) {
    if (summary.hasChild) {
      proceed();
      return;
    }
    showProfileNeededSheet(
      context,
      metrics: metrics,
      onCreate: () => context.go(AppRoutes.authChildStep),
    );
  }
}
