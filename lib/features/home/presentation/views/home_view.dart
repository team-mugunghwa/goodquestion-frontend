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
import '../../domain/entities/recommended_story.dart';
import '../../domain/usecases/get_home_summary_use_case.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/continue_card.dart';
import '../widgets/home_sheets.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/recommended_stories_section.dart';
import '../widgets/start_story_card.dart';

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
/// | 2 | 이어하기 카드 (없으면 "새 이야기 시작" 카드) |
/// | 3 | 추천 이야기 2~3개 (고정 큐레이션) |
/// | 5 | 하단 내비 (고정) |
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

/// 섹션2~4. 스크롤되는 본문입니다.
class _HomeContent extends StatelessWidget {
  const _HomeContent({super.key, required this.summary, required this.metrics});

  final HomeSummary summary;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final session = summary.inProgressSession;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.lg,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (session == null)
            StartStoryCard(
              metrics: metrics,
              onStart: () =>
                  _guarded(context, () => context.go(AppRoutes.stories)),
            )
          else
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
            ),
          SizedBox(height: metrics.sectionGap),
          RecommendedStoriesSection(
            stories: summary.recommendedStories,
            metrics: metrics,
            // push 입니다 — 상세의 뒤로가기가 홈으로 돌아와야 합니다.
            onStoryTap: (RecommendedStory story) => _guarded(
              context,
              () => context.push(AppRoutes.storyDetailOf(story.storyId)),
            ),
            onMoreTap: () => context.go(AppRoutes.stories),
          ),
        ],
      ),
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
