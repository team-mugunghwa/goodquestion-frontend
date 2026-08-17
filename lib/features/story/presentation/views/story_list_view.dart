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
import '../../../../core/widgets/cosmic_backdrop.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/story_card.dart';
import '../../../../core/widgets/story_thumbnail.dart';
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
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 이야기 카드 그리드가 화면을 덮어도, 로딩·빈 상태에서 하늘이
            // 비어 보이지 않게 별과 달을 깔아 둡니다.
            // 내비가 떠 있는 알약이 되면서 달은 화면 바닥까지 내려앉습니다.
            // 알약 뒤로 달이 비쳐 배경과 내비가 한 장면이 됩니다.
            const CosmicBackdrop(seed: 23, planetCenterX: 0.22),
            SafeArea(bottom: false, child: _layout(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, StoryListViewModel vm) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenMetrics metrics = ScreenMetrics.of(constraints.maxWidth);
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
      // 제목 앞 아이콘을 뗐습니다. 아이콘+제목 조합은 제목을 메뉴처럼
      // 보이게 합니다 — 큰 글자 하나가 화면의 얼굴입니다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            StoryListStrings.title,
            style: metrics.text(AppTypography.kidTitle),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            StoryListStrings.subtitle,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink500),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            _grid(context, constraints.maxWidth),
      ),
    );
  }

  Widget _grid(BuildContext context, double width) {
    final int columns = _columnsFor(width);
    return GridView.builder(
      padding: EdgeInsets.only(bottom: metrics.screenPadding),
      itemCount: stories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        // 비율을 눈대중으로 정하면 카드 아래에 흰 여백이 남습니다.
        // 세로 표지(2:3) + 글자 블록을 실제로 더해서 높이를 잡습니다.
        mainAxisExtent: _cellHeightOf(context, metrics, width, columns),
      ),
      itemBuilder: (BuildContext context, int index) {
        final StorySummary story = stories[index];
        return StoryCard(
          title: story.title,
          image: story.image,
          estimatedMinutes: story.estimatedMinutes,
          topicLabel: _topicLabel(story),
          metrics: metrics,
          // 목록은 그림책 세로 표지. 홈 카드(16:9)와 의도적으로 다릅니다.
          coverAspectRatio: StoryThumbnail.portrait,
          // 제목이 잘려 "방귀 뀌는 ..." 이 되면 아이가 이야기를 못 알아봅니다.
          // 두 줄까지 허용해 전체 제목을 보여 줍니다.
          titleMaxLines: 2,
          // go 가 아니라 push — 목록을 스택에 남겨야 상세에서 돌아왔을 때
          // 고른 필터가 그대로입니다.
          onTap: () => context.push(AppRoutes.storyDetailOf(story.storyId)),
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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = _columnsFor(constraints.maxWidth);
          return SkeletonCardList(
            // 한 줄을 다 채워야 목록처럼 보입니다.
            count: columns * 2,
            columns: columns,
            // 실제 카드와 같은 높이여야 데이터가 올 때 안 덜컹입니다.
            mainAxisExtent: _cellHeightOf(
              context,
              metrics,
              constraints.maxWidth,
              columns,
            ),
          );
        },
      ),
    );
  }
}

/// 세로 표지 목록의 열 수.
///
/// 그림책 표지는 세로(2:3)라 한 장이 좁습니다 — 태블릿 가로에서는 한 줄에
/// 여러 장을 꽂아 책장처럼 보입니다. 폭에 목표 표지 폭(~200dp)을 나눠 열을
/// 정하되, 폰(컴팩트)에서도 최소 2열이라 표지가 너무 커지지 않습니다.
int _columnsFor(double width) {
  const double targetCoverWidth = 200;
  final int byWidth = (width / targetCoverWidth).floor();
  return byWidth.clamp(2, 5);
}

/// 그리드 셀 하나의 높이 = 2:3 세로 표지 + 글자 블록.
///
/// `childAspectRatio` 를 눈대중으로 정하면 카드 아래에 흰 여백이 남거나
/// 글자가 잘립니다. 실제로 더해서 잡습니다. 기기의 글자 확대 설정까지
/// 반영하므로 1.3배로 키워도 안 잘립니다.
///
/// 스켈레톤도 같은 값을 써야 데이터가 도착할 때 화면이 안 덜컹입니다.
double _cellHeightOf(
  BuildContext context,
  ScreenMetrics metrics,
  double width,
  int columns,
) {
  final double cellWidth = (width - AppSpacing.lg * (columns - 1)) / columns;
  // 세로 표지(2:3): 너비의 1.5배가 표지 높이.
  final double imageHeight = cellWidth * 3 / 2;
  // 제목은 카드용 크기(kidButton) 두 줄 기준. 한 줄짜리 제목도 같은 셀
  // 높이를 쓰므로 그리드 행이 들쭉날쭉하지 않습니다.
  final double textHeight =
      AppSpacing.md * 2 +
      metrics.lineHeight(context, AppTypography.kidButton) * 2 +
      AppSpacing.sm +
      metrics.lineHeight(context, AppTypography.kidLabel) +
      AppSpacing.xs * 2;
  return imageHeight + textHeight;
}
