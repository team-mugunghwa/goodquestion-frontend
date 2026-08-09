import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/story_card.dart';
import '../../domain/entities/story_summary.dart';
import '../../domain/entities/story_topic.dart';
import '../../domain/usecases/get_story_catalog_use_case.dart';
import '../viewmodels/story_list_view_model.dart';
import '../widgets/topic_chip_bar.dart';

/// 이야기 목록 — 주제로 걸러 하나 고르는 탐색 허브.
///
/// ## 이 화면이 하는 한 가지 일
///
/// **고르기까지만.** 시작 결정(세션 생성)은 상세의 몫입니다. 카드에 난이도·
/// 요약·이어하기 배지를 얹고 싶어지는데, 그 순간 카드가 "읽는 것"이 되고
/// 아이는 그림으로 고르지 못합니다. (PRD F-03)
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 헤더 — "어떤 이야기를 해볼까?" |
/// | 2 | 주제 필터 칩 (가로 스크롤, 단일 선택) |
/// | 3 | 이야기 카드 그리드 (태블릿 2열 · 폰 1열) |
/// | 4 | 하단 내비 (이야기 활성) |
class StoryListPage extends StatelessWidget {
  const StoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoryListViewModel>(
      create: (_) =>
          StoryListViewModel(getIt<GetStoryCatalogUseCase>())..load(),
      child: const StoryListView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class StoryListView extends StatelessWidget {
  const StoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    final StoryListViewModel vm = context.watch<StoryListViewModel>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ScreenMetrics metrics = ScreenMetrics.of(
                constraints.maxWidth,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(metrics: metrics),
                  // 칩은 로딩 중에도 즉시 보입니다. 화면이 텅 비어 보이지
                  // 않게 하는 것도 있지만, 여기가 이 화면의 조작부입니다.
                  if (vm.topics.isNotEmpty) ...<Widget>[
                    TopicChipBar(
                      topics: vm.topics,
                      selectedId: vm.selectedTopicId,
                      onSelected: vm.selectTopic,
                      metrics: metrics,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: respect(context, AppDurations.normal),
                      switchInCurve: AppCurves.standard,
                      switchOutCurve: AppCurves.exit,
                      layoutBuilder: (Widget? current, List<Widget> previous) =>
                          Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                      child: _body(context, vm, metrics),
                    ),
                  ),
                  const AppBottomNav(current: AppNavTab.stories),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    StoryListViewModel vm,
    ScreenMetrics metrics,
  ) {
    if (vm.state.isError) {
      return AppKidErrorView(
        key: const ValueKey<String>('stories-error'),
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: vm.load,
      );
    }
    if (!vm.state.isSuccess) {
      return _Skeleton(
        key: const ValueKey<String>('stories-skeleton'),
        metrics: metrics,
      );
    }
    if (vm.isEmptyByFilter) {
      // 막다른 길을 만들지 않습니다 — 전체로 돌아가는 문을 함께 줍니다.
      return AppKidEmptyView(
        key: const ValueKey<String>('stories-empty'),
        message: StoryListStrings.emptyTopic,
        actionIcon: AppIcons.topicAll,
        actionLabel: StoryListStrings.showAll,
        messageStyle: metrics.text(AppTypography.kidBody),
        onAction: vm.resetTopic,
      );
    }
    return _Grid(
      // 칩을 바꿔도 그리드가 통째로 페이드하지 않도록 키를 고정합니다.
      // 바뀌는 건 카드지 화면이 아닙니다.
      key: const ValueKey<String>('stories-grid'),
      stories: vm.visibleStories,
      topics: vm.topics,
      metrics: metrics,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.md,
        metrics.screenPadding,
        AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            AppIcons.stories,
            size: AppSizes.iconChild,
            color: AppColors.brandBlueDeep,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              StoryListStrings.title,
              style: metrics.text(AppTypography.kidTitle),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 그리드. 태블릿 2열, 폰 1열.
///
/// 폰에서 2열을 유지하면 카드가 반으로 줄어 그림이 안 보입니다 —
/// 폭이 좁으면 **열을 줄입니다.** (`docs/ARCHITECTURE.md` 7장)
class _Grid extends StatelessWidget {
  const _Grid({
    super.key,
    required this.stories,
    required this.topics,
    required this.metrics,
  });

  final List<StorySummary> stories;
  final List<StoryTopic> topics;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        0,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      itemCount: stories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.gridColumns,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        // 이미지(16:9)가 카드 면적을 지배하도록 잡은 비율입니다.
        childAspectRatio: metrics.isWide ? 3 / 4 : 16 / 11,
      ),
      itemBuilder: (BuildContext context, int index) {
        final StorySummary story = stories[index];
        return StoryCard(
          title: story.title,
          image: story.image,
          estimatedMinutes: story.estimatedMinutes,
          topicLabel: _topicLabel(story),
          metrics: metrics,
          // 목록 카드의 제목은 큰 글씨 한 줄. (PRD F-03)
          titleMaxLines: 1,
          // go 가 아니라 push — 목록을 스택에 남겨야 상세에서 돌아왔을 때
          // 고른 필터가 그대로입니다.
          onTap: () =>
              context.push(AppRoutes.storyDetailOf('${story.storyId}')),
        );
      },
    );
  }

  /// 카드에는 주제를 **하나만** 보여 줍니다. 두 개를 붙이면 배지가 제목보다
  /// 길어져서, 아이 눈에는 카드가 글자 덩어리로 보입니다.
  String _topicLabel(StorySummary story) {
    if (story.topicIds.isEmpty) return '';
    final String first = story.topicIds.first;
    for (final StoryTopic topic in topics) {
      if (topic.id == first) return topic.label;
    }
    // 앱이 모르는 주제라도 카드가 비지 않게 id 를 그대로 보여 줍니다.
    return first;
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: SkeletonCardList(
        count: metrics.isWide ? 4 : 3,
        columns: metrics.gridColumns,
        aspectRatio: metrics.isWide ? 3 / 4 : 16 / 11,
      ),
    );
  }
}
