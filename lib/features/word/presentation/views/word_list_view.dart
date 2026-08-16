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
import '../../../../core/widgets/kid_chips.dart';
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
            // 내비가 떠 있는 알약이라 달을 화면 바닥까지 내립니다.
            const CosmicBackdrop(seed: 11, planetCenterX: 0.78),
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
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              WordStrings.title,
              style: metrics.text(AppTypography.kidTitle),
            ),
          ),
          if (vm.state.isSuccess)
            Semantics(
              label: WordStrings.savedCount(vm.totalCount),
              excludeSemantics: true,
              child: KidInfoChip(
                icon: AppIcons.savedWord,
                label: '${vm.totalCount}',
                metrics: metrics,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          _Avatar(name: vm.childName, image: vm.childAvatar),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.image});

  final String? name;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final String? avatar = image;
    return ClipOval(
      child: SizedBox.square(
        dimension: AppSizes.tapChildSecondary,
        child: avatar != null
            ? Image.asset(
                avatar,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
                    const _AvatarFallback(),
              )
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.brandMint,
    child: Icon(
      AppIcons.childProfile,
      size: AppSizes.iconInline,
      color: AppColors.ink900,
    ),
  );
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
            for (final SavedWord word in group.words) ...<Widget>[
              WordCard(
                word: word,
                metrics: metrics,
                onTap: () => _openDetail(context, word),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox.square(
            dimension: AppSizes.tapChildSecondary,
            child: StoryThumbnail(
              image: group.storyImage,
              fallbackIcon: AppIcons.stories,
              aspectRatio: StoryThumbnail.square,
              iconSize: AppSizes.iconInline,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            group.storyTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics.text(AppTypography.kidTitle),
          ),
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
