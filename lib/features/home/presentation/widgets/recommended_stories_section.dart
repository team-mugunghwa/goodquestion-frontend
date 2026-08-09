import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../domain/entities/recommended_story.dart';
import 'home_metrics.dart';
import 'story_thumbnail.dart';

/// 섹션3 — 추천 이야기. 고정 큐레이션 2~3개.
///
/// 개인화 추천은 MVP 범위 밖입니다. 여기서 하는 일은 "다음에 뭐 할래?"에
/// 대한 **선택지를 세 개 이하로 줄여 주는 것** 하나뿐입니다.
class RecommendedStoriesSection extends StatelessWidget {
  const RecommendedStoriesSection({
    super.key,
    required this.stories,
    required this.metrics,
    required this.onStoryTap,
    required this.onMoreTap,
  });

  final List<RecommendedStory> stories;
  final HomeMetrics metrics;
  final void Function(RecommendedStory story) onStoryTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                HomeStrings.recommendedTitle,
                style: metrics.text(AppTypography.kidTitle),
              ),
            ),
            _MoreButton(metrics: metrics, onTap: onMoreTap),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (stories.isEmpty)
          // 큐레이션이 비는 건 기획 사고지만, 그래도 화면이 무너지면 안 됩니다.
          Text(
            HomeStrings.recommendedEmpty,
            style: metrics.text(AppTypography.kidBody),
          )
        else if (metrics.isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < stories.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: StoryCard(
                    story: stories[i],
                    metrics: metrics,
                    horizontal: false,
                    onTap: () => onStoryTap(stories[i]),
                  ),
                ),
              ],
            ],
          )
        else
          // 폰에서는 카드를 줄이지 않고 **세로로 눕힙니다.** 가로 스크롤은
          // 아이가 오른쪽에 더 있다는 걸 모르면 아예 못 봅니다.
          Column(
            children: <Widget>[
              for (int i = 0; i < stories.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                StoryCard(
                  story: stories[i],
                  metrics: metrics,
                  horizontal: true,
                  onTap: () => onStoryTap(stories[i]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.metrics, required this.onTap});

  final HomeMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      semanticLabel: '${HomeStrings.recommendedTitle} ${HomeStrings.more}',
      child: Container(
        height: AppSizes.tapChildSecondary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              HomeStrings.more,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.brandBlueDeep),
            ),
            const Icon(
              AppIcons.chevronRight,
              size: AppSizes.iconInline,
              color: AppColors.brandBlueDeep,
            ),
          ],
        ),
      ),
    );
  }
}

/// 이야기 카드. 대표 이미지 + 제목 + 시간·주제 칩.
///
/// 난이도는 노출하지 않습니다 — 홈에서 아이가 할 판단은 "이거 재밌어
/// 보인다" 하나입니다. 상세 정보는 이야기 상세 화면 몫입니다.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.metrics,
    required this.onTap,
    this.horizontal = false,
  });

  final RecommendedStory story;
  final HomeMetrics metrics;
  final VoidCallback onTap;

  /// 폰에서 쓰는 가로 배치(썸네일 왼쪽 · 글자 오른쪽).
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final Widget thumbnail = StoryThumbnail(
      image: story.image,
      fallbackIcon: AppIcons.stories,
      // 가로 배치에서 16:9 를 쓰면 이미지가 납작해져서 제목 옆에 붙은
      // 장식처럼 보입니다. 정사각이 글자 블록 높이와 맞습니다.
      aspectRatio: horizontal ? StoryThumbnail.square : StoryThumbnail.wide,
    );
    final Widget body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            story.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: metrics.text(AppTypography.kidTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _InfoChip(
                icon: AppIcons.duration,
                label: HomeStrings.minutes(story.estimatedMinutes),
                metrics: metrics,
              ),
              _InfoChip(label: story.topicTag, metrics: metrics),
            ],
          ),
        ],
      ),
    );

    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel:
          '${story.title} · '
          '${HomeStrings.minutes(story.estimatedMinutes)} · ${story.topicTag}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(flex: 4, child: thumbnail),
                  Expanded(flex: 6, child: body),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[thumbnail, body],
              ),
      ),
    );
  }
}

/// 시간·주제 칩. 파스텔은 **면**으로만 쓰고 글자는 잉크색입니다.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.metrics, this.icon});

  final String label;
  final HomeMetrics metrics;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? glyph = icon;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            Icon(glyph, size: AppSizes.iconInline, color: AppColors.ink700),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: metrics.text(AppTypography.kidLabel)),
        ],
      ),
    );
  }
}
