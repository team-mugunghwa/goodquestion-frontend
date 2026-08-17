import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/cosmic_backdrop.dart';
import '../../../../core/widgets/kid_chips.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/usecases/get_word_book_use_case.dart';
import '../../domain/usecases/toggle_word_like_use_case.dart';
import '../viewmodels/word_list_view_model.dart';
import '../widgets/word_card.dart';
import '../widgets/word_detail_sheet.dart';

/// 단어장 — 이야기 속에서 담아 둔 단어를 다시 만나는 화면.
///
/// ## 이 화면이 하는 한 가지 일
///
/// **읽는 화면이 아니라 다시 만나는 화면.** 목록에 뜻을 노출하면 텍스트
/// 밀도가 올라가 저학년이 이탈합니다 — 뜻·예문은 상세 모달로만. (PRD F-10)
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 헤더 — "내 단어장" · 아바타 · 담은 개수 배지 |
/// | 2 | 이야기 필터 칩 (가로 스크롤) |
/// | 3 | 이야기 그룹 헤더 + 단어 카드 |
/// | 4 | 하단 내비 (단어장 활성) |
///
/// 그룹 기준은 **이야기**입니다. 저장 시각순 평면 리스트로 만들지 마세요 —
/// 아이의 기억 단서는 "어떤 이야기에서 만났나"입니다.
class WordListPage extends StatelessWidget {
  const WordListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WordListViewModel>(
      create: (_) => WordListViewModel(
        getIt<GetWordBookUseCase>(),
        getIt<ToggleWordLikeUseCase>(),
      )..load(),
      child: const WordListView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class WordListView extends StatelessWidget {
  const WordListView({super.key});

  @override
  Widget build(BuildContext context) {
    final WordListViewModel vm = context.watch<WordListViewModel>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 담은 단어는 "내 행성"으로 가져가는 재산 — 배경도 같은 세계관.
            // 달이 유리 내비 뒤에 반쯤 가리면 있는 줄도 모릅니다.
            // 내비 블록(위 여백 + 바 + 아래 여백) 높이만큼 올려 앉힙니다.
            const CosmicBackdrop(
              seed: 11,
              planetCenterX: 0.78,
              bottomInset: AppSizes.bottomNav + AppSpacing.lg,
            ),
            SafeArea(bottom: false, child: _layout(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, WordListViewModel vm) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenMetrics metrics = ScreenMetrics.of(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(vm: vm, metrics: metrics),
            // 담은 게 하나도 없으면 필터 칩을 숨깁니다 —
            // 거를 것이 없는데 칩만 남으면 고장으로 보입니다.
            if (!vm.isEmpty && vm.allGroups.isNotEmpty) ...<Widget>[
              _StoryChips(vm: vm, metrics: metrics),
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
            const AppBottomNav(current: AppNavTab.words),
          ],
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    WordListViewModel vm,
    ScreenMetrics metrics,
  ) {
    if (vm.state.isError) {
      return AppKidErrorView(
        key: const ValueKey<String>('words-error'),
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: vm.load,
      );
    }
    if (!vm.state.isSuccess) {
      return _Skeleton(
        key: const ValueKey<String>('words-skeleton'),
        metrics: metrics,
      );
    }
    if (vm.isEmpty) {
      // 담은 단어가 없는 건 실패가 아닙니다. 본체 활동으로 보냅니다.
      return AppKidEmptyView(
        key: const ValueKey<String>('words-empty'),
        message: WordStrings.empty,
        actionIcon: AppIcons.stories,
        actionLabel: WordStrings.goToStories,
        messageStyle: metrics.text(AppTypography.kidBody),
        onAction: () => context.go(AppRoutes.stories),
      );
    }
    if (vm.isEmptyByFilter) {
      // 어느 필터 때문에 비었는지에 따라 나가는 문이 다릅니다.
      // 좋아요 필터를 켠 채로 "전체 이야기"를 눌러도 여전히 비어 있으면
      // 아이는 앱이 고장 난 줄 압니다.
      if (vm.likedOnly) {
        return AppKidEmptyView(
          key: const ValueKey<String>('words-empty-liked'),
          message: WordStrings.emptyLiked,
          actionIcon: AppIcons.likeOff,
          actionLabel: WordStrings.showAllWords,
          messageStyle: metrics.text(AppTypography.kidBody),
          onAction: vm.toggleLikedOnly,
        );
      }
      return AppKidEmptyView(
        key: const ValueKey<String>('words-empty-filter'),
        message: WordStrings.emptyInStory,
        actionIcon: AppIcons.topicAll,
        actionLabel: AppStrings.filterAll,
        messageStyle: metrics.text(AppTypography.kidBody),
        onAction: () => vm.selectStory(WordListViewModel.allStoryId),
      );
    }
    return _GroupList(
      key: const ValueKey<String>('words-list'),
      vm: vm,
      metrics: metrics,
    );
  }
}

/// 섹션1 — 제목 · 아바타 · 담은 개수.
///
/// 개수 배지에 **노란 별을 쓰지 않습니다.** 기획 시안은 별 배지였지만,
/// 이 앱에서 노랑은 별가루(보상) 전용이라 단어 개수에 쓰면 아이가 보상으로
/// 착각합니다. 파스텔 면 + 북마크 아이콘으로 바꿨습니다.
/// (`docs/DESIGN_SYSTEM.md` 3장)
class _Header extends StatelessWidget {
  const _Header({required this.vm, required this.metrics});

  final WordListViewModel vm;
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
      // 제목 + 부제 두 줄. 개수 배지를 따로 달지 않고 부제 문장에 녹입니다.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  WordStrings.title,
                  style: metrics.text(AppTypography.kidTitle),
                ),
                if (vm.state.isSuccess) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: WordStrings.savedCount(vm.totalCount),
                    excludeSemantics: true,
                    child: Text(
                      WordStrings.subtitle(vm.totalCount),
                      style: metrics
                          .text(AppTypography.kidLabel)
                          .copyWith(color: AppColors.ink500),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 아바타를 뗐습니다. 누를 수도 없고 "누구의 단어장인지"는 이미
          // 홈에서 정해져 오는 정보라, 헤더 오른쪽 자리는 **조작부**가
          // 차지하는 편이 낫습니다. 좋아요 필터가 여기 옵니다.
          if (vm.likedCount > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            _LikedFilterButton(
              key: const ValueKey<String>('words-liked-filter'),
              vm: vm,
              metrics: metrics,
            ),
          ],
        ],
      ),
    );
  }
}

/// 좋아요한 단어만 보기. 하트를 누르는 이유가 되는 자리입니다.
///
/// 켜진 상태는 색만이 아니라 **채워진 하트**로도 구분합니다 —
/// 색을 구분하기 어려운 아이도 지금 걸러진 상태인지 알아야 합니다.
class _LikedFilterButton extends StatelessWidget {
  const _LikedFilterButton({
    super.key,
    required this.vm,
    required this.metrics,
  });

  final WordListViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final bool on = vm.likedOnly;
    final Color foreground = on ? AppColors.surface : AppColors.brandBlueDeep;
    return Semantics(
      selected: on,
      button: true,
      child: PressScale(
        onTap: vm.toggleLikedOnly,
        borderRadius: AppRadius.pill,
        semanticLabel: WordStrings.likedOnly,
        child: Container(
          height: AppSizes.tapChildSecondary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: on ? AppColors.brandBlueDeep : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                on ? AppIcons.like : AppIcons.likeOff,
                size: AppSizes.iconInline,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${vm.likedCount}',
                style: metrics
                    .text(AppTypography.kidLabel)
                    .copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션2 — 이야기 필터. 글자보다 **이야기 대표 이미지**가 앞섭니다.
class _StoryChips extends StatelessWidget {
  const _StoryChips({required this.vm, required this.metrics});

  final WordListViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return KidFilterChips(
      metrics: metrics,
      selectedId: vm.selectedStoryId,
      onSelected: vm.selectStory,
      items: <KidFilterChipData>[
        const KidFilterChipData(
          id: WordListViewModel.allStoryId,
          label: AppStrings.filterAll,
          icon: AppIcons.topicAll,
        ),
        // 이름 없는 묶음은 칩으로 만들지 않습니다 — 라벨이 빈 칩이 됩니다.
        for (final WordGroup group in vm.allGroups)
          if (group.hasStory)
            KidFilterChipData(
              id: group.filterKey,
              label: group.storyTitle,
              image: group.storyImage,
            ),
      ],
    );
  }
}

/// 섹션3 — 이야기 그룹 헤더 + 단어 카드.
class _GroupList extends StatelessWidget {
  const _GroupList({super.key, required this.vm, required this.metrics});

  final WordListViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final List<WordGroup> groups = vm.visibleGroups;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        0,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: metrics.sectionGap),
      itemBuilder: (BuildContext context, int index) {
        final WordGroup group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 이야기를 모르는 묶음에는 **헤더를 그리지 않습니다.** 붙일 이름이
            // 없는데 억지로 지어내면, 아이는 그게 이야기 제목인 줄 압니다.
            if (group.hasStory) ...<Widget>[
              _GroupHeader(group: group, metrics: metrics),
              const SizedBox(height: AppSpacing.md),
            ],
            // 태블릿(넓은 폭)에서는 2열 타일로 깔아 세로 스크롤을 줄입니다.
            // 전폭 리스트는 넓은 화면에서 오른쪽 절반이 빈 채로 흘러갑니다.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = metrics.isWide ? 2 : 1;
                final double width =
                    (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                    columns;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    for (final SavedWord word in group.words)
                      SizedBox(
                        width: width,
                        child: WordCard(
                          word: word,
                          metrics: metrics,
                          onTap: () => _openDetail(context, word),
                          onToggleLike: () => vm.toggleLike(word.wordId),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, SavedWord word) {
    showWordDetailSheet(
      context,
      word: word,
      metrics: metrics,
      onToggleLike: () => vm.toggleLike(word.wordId),
      latest: () => vm.wordOf(word.wordId),
      // 시트가 닫힌 뒤 이 context(목록)에서 push 합니다. 상세로 가는 건
      // context.go 가 아니라 push - 돌아왔을 때 필터가 남아야 합니다.
      onPractice: () => context.push(
        AppRoutes.wordPracticeOf(word.wordId),
        extra: vm.wordOf(word.wordId) ?? word,
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.metrics});

  final WordGroup group;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final String? cover = group.storyImage;
    return Row(
      children: <Widget>[
        // 표지가 있을 때만 그립니다. 없을 때 책 아이콘을 원에 박아 넣던
        // 예전 폴백은 이야기마다 똑같은 그림이 반복돼 자리만 먹었습니다.
        // 모서리는 원이 아니라 둥근 사각 — 표지는 얼굴이 아니라 그림입니다.
        if (cover != null) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox.square(
              dimension: AppSizes.iconChild,
              child: StoryThumbnail(
                image: cover,
                fallbackIcon: AppIcons.stories,
                aspectRatio: StoryThumbnail.square,
                iconSize: AppSizes.iconCaption,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        // 화면 제목(32)과 같은 크기를 쓰면 묶음 이름이 화면의 주인처럼
        // 보입니다. 한 단계 낮춰 "내 단어장 > 이야기" 순서를 만듭니다.
        Flexible(
          child: Text(
            group.storyTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics
                .text(AppTypography.kidButton)
                .copyWith(color: AppColors.ink900),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // 몇 개가 들어 있는지. 묶음을 접었다 펴지 않으므로 개수가
        // 여기서 유일한 규모 신호입니다.
        Text(
          WordStrings.groupCount(group.words.length),
          style: metrics
              .text(AppTypography.kidCaption)
              .copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SkeletonBox(width: 200, height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < 3; i++) ...<Widget>[
            const SkeletonBox(
              height: AppSizes.tapChildPrimary,
              borderRadius: AppRadius.xl,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
