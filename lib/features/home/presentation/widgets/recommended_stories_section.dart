import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_card.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/recommended_story.dart';

/// 섹션3 — 추천 이야기. 고정 큐레이션 2~3개.
///
/// 개인화 추천은 MVP 범위 밖입니다. 여기서 하는 일은 "다음에 뭐 할래?"에
/// 대한 **선택지를 세 개 이하로 줄여 주는 것** 하나뿐입니다.
///
/// 카드는 이야기 목록(`/stories`)과 **같은 [StoryCard]** 를 씁니다.
class RecommendedStoriesSection extends StatelessWidget {
  const RecommendedStoriesSection({
    super.key,
    required this.stories,
    required this.metrics,
    required this.onStoryTap,
    required this.onMoreTap,
  });

  final List<RecommendedStory> stories;
  final ScreenMetrics metrics;
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
              child: _SectionHeading(
                text: HomeStrings.recommendedTitle,
                metrics: metrics,
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
          // 태블릿에서도 **가로 카드**입니다. 세로 카드를 3장 늘어놓으면
          // 표지 하나가 화면 높이의 절반을 먹어서 추천이 접히는 곳 아래로
          // 내려갑니다. 여기는 목록이 아니라 "다음에 뭐 할래?" 한 줄입니다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < stories.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.lg),
                Expanded(child: _card(stories[i], horizontal: true)),
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
                _card(stories[i], horizontal: true),
              ],
            ],
          ),
      ],
    );
  }

  Widget _card(RecommendedStory story, {required bool horizontal}) => StoryCard(
    title: story.title,
    image: story.image,
    estimatedMinutes: story.estimatedMinutes,
    topicLabel: story.topicTag,
    metrics: metrics,
    horizontal: horizontal,
    // 표지 원본이 그림책 세로 판형(2:3)입니다. 16:9 나 정사각으로 깔면
    // 그림이 잘려 인물 얼굴이 날아갑니다. 원본 비율 그대로 둡니다.
    coverAspectRatio: StoryThumbnail.portrait,
    onTap: () => onStoryTap(story),
  );
}

/// 섹션 제목.
///
/// 예전에는 마지막 단어만 브랜드 색으로 강조했는데, 한 제목 안에서 글자
/// 색이 갈리면 두 문장처럼 읽히고 다른 화면 제목과도 어긋납니다.
/// 제목은 어디서나 한 가지 잉크색입니다. (`docs/DESIGN_SYSTEM.md` 3장)
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text, required this.metrics});

  final String text;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: metrics.text(AppTypography.kidTitle));
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.metrics, required this.onTap});

  final ScreenMetrics metrics;
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
