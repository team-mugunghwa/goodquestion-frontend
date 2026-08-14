import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_card.dart';
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < stories.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.lg),
                Expanded(child: _card(stories[i], horizontal: false)),
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
    onTap: () => onStoryTap(story),
  );
}

/// 섹션 제목. 레퍼런스처럼 **마지막 단어(키워드)만 브랜드 색**으로 강조합니다.
///
/// 파스텔은 글자로 못 쓰므로 강조는 대비가 나오는 `brandBlueDeep` 로.
/// (노랑은 별가루 전용이라 강조에 쓰지 않습니다 — `docs/DESIGN_SYSTEM.md` 3장)
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text, required this.metrics});

  final String text;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = metrics.text(AppTypography.kidTitle);
    final int split = text.lastIndexOf(' ');
    final String lead = split < 0 ? '' : text.substring(0, split + 1);
    final String keyword = split < 0 ? text : text.substring(split + 1);
    return RichText(
      text: TextSpan(
        style: base,
        children: <TextSpan>[
          if (lead.isNotEmpty) TextSpan(text: lead),
          TextSpan(
            text: keyword,
            style: base.copyWith(color: AppColors.brandBlueDeep),
          ),
        ],
      ),
    );
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
